//
//  ReactableInstrument.swift
//  ReactableKit
//
//  Reactable cycle instrumentation.
//
//  Every stage of the cycle is reported as an `os_signpost` interval so it shows up on the
//  Instruments timeline, and anything slower than a threshold is logged as a warning:
//
//      action(_:) ─▶ [Queue] ─▶ [Mutate] ─▶ [Effect] ─▶ [Reduce] ─▶ state
//
//  - `Queue`  the time an action waited on the main queue before `mutate` picked it up.
//             A healthy cycle with a growing queue latency means the main queue is backed up —
//             per-stage durations alone will not show that.
//  - `Mutate` the synchronous cost of building the mutation publisher.
//  - `Effect` the lifetime of that publisher, from subscription to completion.
//  - `Reduce` the synchronous cost of applying a mutation to the state.
//
//  Signposts, statistics, and warnings are available only in DEBUG builds. Target lifecycle
//  events are available in all builds and are opt-in through `instrumentation` and `onTargetEvent`.
//
//  Instruments recipe: Edit Scheme ▸ Profile ▸ Build Configuration = Debug, then ⌘I, add the
//  "os_signpost" instrument and look for subsystem `ReactableInstrument.subsystem`,
//  category `Reactable`.
//

import Foundation

#if DEBUG
import Combine
import os
#endif

public enum ReactableInstrument {

    // MARK: - Options

    public struct Options<Action: Sendable>: Sendable {
        public var label: String?
        public var warningThreshold: TimeInterval?
        public var targets: [Target<Action>]

        public static var `default`: Self { .init() }

        public init(
            label: String? = nil,
            warningThreshold: TimeInterval? = nil,
            targets: [Target<Action>] = []
        ) {
            self.label = label
            self.warningThreshold = warningThreshold
            self.targets = targets
        }
    }

    public enum Stage: String, Hashable, Sendable, CaseIterable {
        case queue
        case mutate
        case effect
        case reduce
    }

    public struct TargetID: Hashable, Sendable, RawRepresentable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public struct Target<Action: Sendable>: Sendable {
        /// Build configurations in which the target callback receives lifecycle events.
        public enum BuildConfiguration: Hashable, Sendable {
            case debugOnly
            case releaseOnly
            case all
        }

        public let id: TargetID
        public let stages: Set<Stage>
        public let buildConfiguration: BuildConfiguration
        private let includesAction: @Sendable (Action) -> Bool

        public init(
            _ id: TargetID,
            observing stages: Set<Stage>,
            emittingIn buildConfiguration: BuildConfiguration = .debugOnly,
            _ includes: @escaping @Sendable (Action) -> Bool = { _ in true }
        ) {
            self.id = id
            self.stages = stages
            self.buildConfiguration = buildConfiguration
            self.includesAction = includes
        }

        internal func includes(_ action: Action) -> Bool {
            self.includesAction(action)
        }

        internal var emitsInCurrentBuild: Bool {
            #if DEBUG
            self.buildConfiguration != .releaseOnly
            #else
            self.buildConfiguration != .debugOnly
            #endif
        }
    }

    public struct MeasurementID: Hashable, Sendable {
        public let target: TargetID
        public let cycle: UInt64
        public let stage: Stage
        public let occurrence: UInt64

        public init(
            target: TargetID,
            cycle: UInt64,
            stage: Stage,
            occurrence: UInt64 = 0
        ) {
            self.target = target
            self.cycle = cycle
            self.stage = stage
            self.occurrence = occurrence
        }
    }

    public struct TargetEventContext: Sendable {
        public let id: MeasurementID
        public let reactable: String

        public init(id: MeasurementID, reactable: String) {
            self.id = id
            self.reactable = reactable
        }
    }

    public enum TargetEvent: Sendable {
        case started(TargetEventContext)
        case finished(TargetEventContext, duration: TimeInterval)
        case cancelled(TargetEventContext, duration: TimeInterval)
    }

    private static let targetEventLock = NSLock()
    private nonisolated(unsafe) static var _onTargetEvent: (@Sendable (TargetEvent) -> Void)?
    private nonisolated(unsafe) static var nextTargetCycle: UInt64 = 0
    private nonisolated(unsafe) static var nextTargetOccurrence: UInt64 = 0

    /// Receives selected target lifecycle events. Install the callback before a Reactable stream is created.
    public static var onTargetEvent: (@Sendable (TargetEvent) -> Void)? {
        get { self.targetEventLock.perform { self._onTargetEvent } }
        set { self.targetEventLock.perform { self._onTargetEvent = newValue } }
    }

    internal static func makeTargetCycle() -> UInt64 {
        self.targetEventLock.perform {
            self.nextTargetCycle &+= 1
            return self.nextTargetCycle
        }
    }

    internal static func makeTargetOccurrence() -> UInt64 {
        self.targetEventLock.perform {
            self.nextTargetOccurrence &+= 1
            return self.nextTargetOccurrence
        }
    }

    internal static func targetEventHandler() -> (@Sendable (TargetEvent) -> Void)? {
        self.targetEventLock.perform { self._onTargetEvent }
    }

    // MARK: - Timing

    /// Monotonic timestamp in nanoseconds. Not affected by wall-clock adjustments, unlike `Date`.
    @inline(__always)
    public static func timestamp() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    @inline(__always)
    public static func elapsed(since start: UInt64) -> TimeInterval {
        self.duration(from: start, to: self.timestamp())
    }

    /// Interval between two `timestamp()` readings. Used when several measurements share a single
    /// end reading, so they all report against the same instant.
    @inline(__always)
    internal static func duration(from start: UInt64, to end: UInt64) -> TimeInterval {
        guard end > start else { return 0 }
        return TimeInterval(end - start) / 1_000_000_000
    }

    #if DEBUG
    // MARK: - Events

    /// A single measurement. Delivered to `onEvent` regardless of whether it exceeded the
    /// threshold, so a debug tool can render every cycle rather than only the slow ones.
    public enum Event: Sendable {
        /// Time an action spent waiting on the main queue before `mutate` ran.
        case queueLatency(reactable: String, action: String, duration: TimeInterval)
        /// Synchronous cost of `mutate(action:)`.
        case mutate(reactable: String, action: String, duration: TimeInterval)
        /// Lifetime of the publisher returned by `mutate(action:)`.
        case effect(reactable: String, action: String, duration: TimeInterval)
        /// Synchronous cost of `reduce(state:mutation:)`.
        case reduce(reactable: String, mutation: String, duration: TimeInterval)

        public var stage: Stage {
            switch self {
            case .queueLatency: return .queue
            case .mutate: return .mutate
            case .effect: return .effect
            case .reduce: return .reduce
            }
        }

        public var duration: TimeInterval {
            switch self {
            case let .queueLatency(_, _, duration),
                 let .mutate(_, _, duration),
                 let .effect(_, _, duration),
                 let .reduce(_, _, duration):
                return duration
            }
        }

        public var reactable: String {
            switch self {
            case let .queueLatency(reactable, _, _),
                 let .mutate(reactable, _, _),
                 let .effect(reactable, _, _),
                 let .reduce(reactable, _, _):
                return reactable
            }
        }

        /// The action or mutation case name this measurement belongs to.
        public var name: String {
            switch self {
            case let .queueLatency(_, name, _),
                 let .mutate(_, name, _),
                 let .effect(_, name, _),
                 let .reduce(_, name, _):
                return name
            }
        }
    }

    // MARK: - Configuration

    private static let lock = NSRecursiveLock()
    private nonisolated(unsafe) static var _subsystem: String = Bundle.main.bundleIdentifier ?? "ReactableKit"
    private nonisolated(unsafe) static var _warningThreshold: TimeInterval = 0.05
    private nonisolated(unsafe) static var _warningInterval: TimeInterval = 1.0
    private nonisolated(unsafe) static var _statisticsEnabled: Bool = true
    private nonisolated(unsafe) static var _enabledByDefault: Bool = false
    private nonisolated(unsafe) static var _onEvent: (@Sendable (Event) -> Void)?
    private nonisolated(unsafe) static var _filter: (@Sendable (String) -> Bool)?
    private nonisolated(unsafe) static var _logger: Logger?
    private nonisolated(unsafe) static var _signposter: OSSignposter?

    /// Subsystem used for both the signposts and the warning log. Defaults to the app's bundle
    /// identifier so a shared package does not hardcode any one app's identifier.
    /// Set this before the first measurement; changing it rebuilds the logger and signposter.
    public static var subsystem: String {
        get { self.lock.perform { self._subsystem } }
        set {
            self.lock.perform {
                self._subsystem = newValue
                self._logger = nil
                self._signposter = nil
            }
        }
    }

    /// Global warning threshold. A stage taking at least this long is logged as a warning.
    /// `Options.warningThreshold` overrides it per Reactable.
    ///
    /// The default of 50 ms comes from high-frequency streams: work driven at a 0.5 s cadence has
    /// to finish well inside that cadence or the queue backs up, so 10% of it is the budget.
    public static var warningThreshold: TimeInterval {
        get { self.lock.perform { self._warningThreshold } }
        set { self.lock.perform { self._warningThreshold = newValue } }
    }

    /// Minimum time between two warnings for the same reactable/stage/case. Keeps a high-frequency
    /// stream from flooding the log; statistics still record every sample.
    public static var warningInterval: TimeInterval {
        get { self.lock.perform { self._warningInterval } }
        set { self.lock.perform { self._warningInterval = newValue } }
    }

    /// Whether per-case statistics are accumulated for `report()`. Turning this off lets the
    /// instrument skip building case-name strings entirely when nothing else needs them.
    public static var statisticsEnabled: Bool {
        get { self.lock.perform { self._statisticsEnabled } }
        set { self.lock.perform { self._statisticsEnabled = newValue } }
    }

    /// Instrument every Reactable, including those that never override `instrumentation`.
    public static var enabledByDefault: Bool {
        get { self.lock.perform { self._enabledByDefault } }
        set {
            self.lock.perform {
                self._enabledByDefault = newValue
                self.refreshGlobalEnablement()
            }
        }
    }

    /// Observer hook for external debug tooling. Receives every measurement, slow or not.
    public static var onEvent: (@Sendable (Event) -> Void)? {
        get { self.lock.perform { self._onEvent } }
        set { self.lock.perform { self._onEvent = newValue } }
    }

    /// Enables instrumentation for the Reactable type names this returns `true` for.
    /// Evaluated only for Reactables that did not opt in themselves.
    public static var filter: (@Sendable (String) -> Bool)? {
        get { self.lock.perform { self._filter } }
        set {
            self.lock.perform {
                self._filter = newValue
                self.refreshGlobalEnablement()
            }
        }
    }

    /// Set `REACTABLE_INSTRUMENT` to `1`, `YES`, or `true` in the scheme's environment variables to
    /// instrument everything without touching any code. Read once per process.
    public static let environmentEnabled: Bool = {
        guard let value = ProcessInfo.processInfo.environment["REACTABLE_INSTRUMENT"]?.lowercased() else {
            return false
        }
        return value == "1" || value == "yes" || value == "true"
    }()

    private static var logger: Logger {
        self.lock.perform {
            if let logger = self._logger { return logger }
            let logger = Logger(subsystem: self._subsystem, category: "ReactableInstrument")
            self._logger = logger
            return logger
        }
    }

    private static var signposter: OSSignposter {
        self.lock.perform {
            if let signposter = self._signposter { return signposter }
            let signposter = OSSignposter(subsystem: self._subsystem, category: "Reactable")
            self._signposter = signposter
            return signposter
        }
    }

    // MARK: - Enablement

    /// Whether any process-wide enablement is currently configured.
    ///
    /// Read without the lock so that a Reactable nobody asked to measure costs one boolean load per
    /// action instead of acquiring a process-wide lock on the framework's hot path. Safe to race on:
    /// a stale `true` only costs one pointless lock acquisition that resolves to `nil`, and a stale
    /// `false` only delays instrumentation by a cycle.
    ///
    /// Recomputed rather than latched, so turning a debug menu's switch back off restores the fast
    /// path instead of leaving every Reactable in the process taking the lock forever.
    private nonisolated(unsafe) static var globalEnablementConfigured = false

    /// Caller must hold `lock`.
    private static func refreshGlobalEnablement() {
        self.globalEnablementConfigured = self._enabledByDefault || self._filter != nil
    }

    /// Resolves the options to measure a cycle with, or `nil` to skip measurement entirely.
    ///
    /// Called once per action, so it stays cheap: a nil check plus one boolean load for the common
    /// case where nothing global is configured. No strings are built here, and the lock is only
    /// taken once some form of global enablement exists.
    ///
    /// Precedence: a Reactable's own `instrumentation` always wins. Otherwise, if a `filter` is set
    /// it decides on its own — a non-matching type name is *not* instrumented even when
    /// `enabledByDefault` or `REACTABLE_INSTRUMENT` is on, so a filter narrows a global switch
    /// rather than widening it.
    public static func resolveOptions<Action: Sendable>(
        name: String,
        instrumentation: Options<Action>?
    ) -> Options<Action>? {
        if let instrumentation { return instrumentation }
        guard self.globalEnablementConfigured || self.environmentEnabled else { return nil }
        return self.lock.perform { () -> Options<Action>? in
            if let filter = self._filter { return filter(name) ? .default : nil }
            if self._enabledByDefault || self.environmentEnabled { return .default }
            return nil
        }
    }

    // MARK: - Measurement

    /// Measures the synchronous cost of building a mutation publisher.
    public static func measureMutate<Action: Sendable, Result>(
        options: Options<Action>,
        reactable: String,
        action: LazyName,
        _ body: () -> Result
    ) -> Result {
        self.measure(stage: .mutate, options: options, reactable: reactable, name: action, body)
    }

    /// Measures the synchronous cost of applying a mutation to the state.
    public static func measureReduce<Action: Sendable>(
        options: Options<Action>,
        reactable: String,
        mutation: LazyName,
        _ body: () -> Void
    ) {
        self.measure(stage: .reduce, options: options, reactable: reactable, name: mutation, body)
    }

    /// Reports how long an action waited on the main queue before `mutate` ran.
    ///
    /// This is the measurement that catches a backed-up main queue: every individual stage can look
    /// healthy while this number grows without bound.
    public static func recordQueueLatency<Action: Sendable>(
        options: Options<Action>,
        reactable: String,
        action: LazyName,
        enqueuedAt: UInt64
    ) {
        let duration = self.elapsed(since: enqueuedAt)
        let signposter = self.signposter
        if signposter.isEnabled {
            signposter.emitEvent(
                "Queue",
                id: signposter.makeSignpostID(),
                """
                \(self.subjectText(options: options, reactable: reactable, name: action.value), privacy: .public) \
                waited \(self.millisText(duration), privacy: .public)
                """
            )
        }
        self.finish(stage: .queue, options: options, reactable: reactable, name: action, duration: duration)
    }

    /// Wraps the publisher returned by `mutate(action:)` so its lifetime shows up as an `Effect`
    /// interval — a synchronous stream produces a short span, a network call produces a long one.
    ///
    /// Unlike the signpost span, the duration itself is always measured, so `onEvent`, the
    /// statistics, and the slow-effect warning work even when Instruments is not recording.
    ///
    /// - Important: this taps the publisher *upstream* of `reduce`, and Combine delivers a value
    ///   synchronously all the way through `reduce` before the completion event arrives. A slow
    ///   `reduce` therefore inflates the `Effect` sample too, producing a second warning for the
    ///   same root cause. When `Slow effect` and `Slow reduce` report the same action, the reduce
    ///   is the cause — the effect is not doing async work.
    public static func measureEffect<Action: Sendable, Output, Failure: Error>(
        _ publisher: AnyPublisher<Output, Failure>,
        options: Options<Action>,
        reactable: String,
        action: LazyName
    ) -> AnyPublisher<Output, Failure> {
        let signposter = self.signposter
        let signpostsEnabled = signposter.isEnabled
        let signpostID = signposter.makeSignpostID()
        let tracker = EffectTracker()

        return publisher
            .handleEvents(
                receiveSubscription: { _ in
                    tracker.start = self.timestamp()
                    guard signpostsEnabled else { return }
                    tracker.interval = signposter.beginInterval(
                        "Effect",
                        id: signpostID,
                        "Started from \(self.subjectText(options: options, reactable: reactable, name: action.value), privacy: .public)"
                    )
                },
                receiveOutput: { _ in
                    guard signpostsEnabled else { return }
                    signposter.emitEvent("Effect Output", id: signpostID, "Output")
                },
                receiveCompletion: { _ in
                    self.endEffect(tracker, signposter: signposter, cancelled: false,
                                   options: options, reactable: reactable, action: action)
                },
                receiveCancel: {
                    self.endEffect(tracker, signposter: signposter, cancelled: true,
                                   options: options, reactable: reactable, action: action)
                }
            )
            .eraseToAnyPublisher()
    }

    private static func endEffect<Action: Sendable>(
        _ tracker: EffectTracker,
        signposter: OSSignposter,
        cancelled: Bool,
        options: Options<Action>,
        reactable: String,
        action: LazyName
    ) {
        guard let start = tracker.finish() else { return }
        if let interval = tracker.takeInterval() {
            if cancelled {
                signposter.endInterval("Effect", interval, "Cancelled")
            } else {
                signposter.endInterval("Effect", interval, "Finished")
            }
        }
        self.finish(
            stage: .effect,
            options: options,
            reactable: reactable,
            name: action,
            duration: self.elapsed(since: start)
        )
    }

    private static func measure<Action: Sendable, Result>(
        stage: Stage,
        options: Options<Action>,
        reactable: String,
        name: LazyName,
        _ body: () -> Result
    ) -> Result {
        let signposter = self.signposter
        var interval: OSSignpostIntervalState?
        if signposter.isEnabled {
            interval = signposter.beginInterval(
                stage.signpostName,
                id: signposter.makeSignpostID(),
                "\(self.subjectText(options: options, reactable: reactable, name: name.value), privacy: .public)"
            )
        }

        let start = self.timestamp()
        let result = body()
        let duration = self.elapsed(since: start)

        if let interval { signposter.endInterval(stage.signpostName, interval) }
        self.finish(stage: stage, options: options, reactable: reactable, name: name, duration: duration)
        return result
    }

    /// Common tail for every stage: warn if slow, accumulate statistics, notify observers.
    ///
    /// The case name is only materialised if something actually needs it, so a Reactable measured
    /// with statistics off and no observer attached pays no reflection cost on a fast cycle.
    private static func finish<Action: Sendable>(
        stage: Stage,
        options: Options<Action>,
        reactable: String,
        name: LazyName,
        duration: TimeInterval
    ) {
        let (threshold, statisticsEnabled, observer) = self.lock.perform {
            (options.warningThreshold ?? self._warningThreshold, self._statisticsEnabled, self._onEvent)
        }
        let isSlow = duration >= threshold
        guard isSlow || statisticsEnabled || observer != nil else { return }

        let resolved = name.value

        if statisticsEnabled {
            self.record(stage: stage, reactable: reactable, name: resolved, duration: duration)
        }
        if isSlow {
            self.warn(
                stage: stage,
                subject: self.subjectText(options: options, reactable: reactable, name: resolved),
                reactable: reactable,
                name: resolved,
                duration: duration,
                threshold: threshold
            )
        }
        observer?(stage.event(reactable: reactable, name: resolved, duration: duration))
    }

    // MARK: - Case names

    /// Extracts an enum case path as `outer(.inner)`.
    ///
    /// Associated values are never dumped: stringifying a large payload on a high-frequency stream
    /// costs more than the code being measured.
    ///
    /// `Action` and `Mutation` are only required to be `Sendable`, so a non-enum value is possible.
    /// Those fall back to the *type* name rather than the value's description: a per-value name
    /// would mint a new statistics key for every sample, growing the tables without bound and
    /// giving each slow cycle a fresh rate-limit window.
    public static func caseName(of value: Any, depth: Int = 2) -> String {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .enum else {
            return String(describing: type(of: value))
        }
        guard let child = mirror.children.first, let label = child.label else {
            return String(String(describing: value).prefix(60))
        }
        guard depth > 1, Mirror(reflecting: child.value).displayStyle == .enum else { return label }
        return "\(label)(.\(self.caseName(of: child.value, depth: depth - 1)))"
    }

    /// A case name that is computed at most once, and only if some part of the instrument asks for
    /// it. Shared by the queue, mutate, and effect measurements of a single action.
    public final class LazyName: @unchecked Sendable {
        private let compute: () -> String
        private let lock = NSLock()
        private var cached: String?

        public init(_ compute: @escaping () -> String) {
            self.compute = compute
        }

        /// Wraps an already-known name.
        public convenience init(resolved: String) {
            self.init { resolved }
        }

        /// Lazily derives the name from an enum value via `caseName(of:)`.
        public static func caseName(of value: @escaping @autoclosure () -> Any) -> LazyName {
            LazyName { ReactableInstrument.caseName(of: value()) }
        }

        public var value: String {
            self.lock.perform {
                if let cached = self.cached { return cached }
                let value = self.compute()
                self.cached = value
                return value
            }
        }
    }

    // MARK: - Statistics

    private struct StatKey: Hashable {
        let reactable: String
        let stage: Stage
        let name: String
    }

    private struct Stat {
        static let bucketCount = 32

        var count: Int = 0
        var total: TimeInterval = 0
        var maximum: TimeInterval = 0
        var buckets = [Int](repeating: 0, count: Stat.bucketCount)

        /// Buckets are powers of two microseconds, so memory stays fixed no matter how many samples
        /// arrive. Bucket 31 covers roughly 35 minutes, well past any latency worth reporting.
        mutating func add(_ duration: TimeInterval) {
            self.count += 1
            self.total += duration
            self.maximum = Swift.max(self.maximum, duration)
            let micros = Swift.max(1.0, duration * 1_000_000)
            let index = Swift.min(Stat.bucketCount - 1, Int(log2(micros)))
            self.buckets[index] += 1
        }

        /// Upper bound of the bucket the requested percentile falls into.
        func percentile(_ percentile: Double) -> TimeInterval {
            guard self.count > 0 else { return 0 }
            let target = Int((Double(self.count) * percentile).rounded(.up))
            var seen = 0
            for (index, value) in self.buckets.enumerated() {
                seen += value
                if seen >= target {
                    return Swift.min(self.maximum, pow(2, Double(index + 1)) / 1_000_000)
                }
            }
            return self.maximum
        }
    }

    private nonisolated(unsafe) static var statistics: [StatKey: Stat] = [:]
    private nonisolated(unsafe) static var lastWarned: [StatKey: UInt64] = [:]
    /// Tracked separately from `statistics` so warning counts stay correct even when
    /// `statisticsEnabled` is off and no `Stat` entry is ever created.
    private nonisolated(unsafe) static var warningCounts: [StatKey: Int] = [:]

    private static func record(stage: Stage, reactable: String, name: String, duration: TimeInterval) {
        let key = StatKey(reactable: reactable, stage: stage, name: name)
        self.lock.perform {
            var stat = self.statistics[key] ?? Stat()
            stat.add(duration)
            self.statistics[key] = stat
        }
    }

    /// A text table of everything measured so far, slowest first. Print it from a debug menu, a
    /// breakpoint, or a test.
    public static func report() -> String {
        let snapshot = self.lock.perform { self.statistics }
        guard !snapshot.isEmpty else { return "ReactableInstrument: no samples recorded." }

        let rows = snapshot
            .sorted { $0.value.maximum > $1.value.maximum }
            .map { key, stat in
                (
                    reactable: key.reactable,
                    stage: key.stage.rawValue,
                    name: key.name,
                    count: "\(stat.count)",
                    p50: self.millisText(stat.percentile(0.5)),
                    p90: self.millisText(stat.percentile(0.9)),
                    max: self.millisText(stat.maximum)
                )
            }

        let reactableWidth = Swift.max(9, rows.map(\.reactable.count).max() ?? 0)
        let stageWidth = Swift.max(5, rows.map(\.stage.count).max() ?? 0)
        let nameWidth = Swift.max(4, rows.map(\.name.count).max() ?? 0)

        func pad(_ text: String, _ width: Int) -> String {
            text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
        }
        func padLeft(_ text: String, _ width: Int) -> String {
            text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
        }

        var lines = [
            "ReactableInstrument report (threshold \(self.millisText(self.warningThreshold)))",
            [
                pad("REACTABLE", reactableWidth),
                pad("STAGE", stageWidth),
                pad("CASE", nameWidth),
                padLeft("COUNT", 7),
                padLeft("P50", 9),
                padLeft("P90", 9),
                padLeft("MAX", 9)
            ].joined(separator: "  ")
        ]
        for row in rows {
            lines.append(
                [
                    pad(row.reactable, reactableWidth),
                    pad(row.stage, stageWidth),
                    pad(row.name, nameWidth),
                    padLeft(row.count, 7),
                    padLeft(row.p50, 9),
                    padLeft(row.p90, 9),
                    padLeft(row.max, 9)
                ].joined(separator: "  ")
            )
        }
        return lines.joined(separator: "\n")
    }

    /// Clears accumulated statistics and the warning rate-limit windows.
    public static func resetStatistics() {
        self.lock.perform {
            self.statistics.removeAll()
            self.lastWarned.removeAll()
            self.warningCounts.removeAll()
        }
    }

    /// Number of samples recorded for a stage. Intended for tests and debug tooling.
    public static func sampleCount(reactable: String, stage: Stage, name: String) -> Int {
        self.lock.perform {
            self.statistics[StatKey(reactable: reactable, stage: stage, name: name)]?.count ?? 0
        }
    }

    /// Number of warnings actually logged for a stage, after rate limiting. Intended for tests and
    /// debug tooling. Always less than or equal to `sampleCount(reactable:stage:name:)`.
    public static func warningCount(reactable: String, stage: Stage, name: String) -> Int {
        self.lock.perform {
            self.warningCounts[StatKey(reactable: reactable, stage: stage, name: name)] ?? 0
        }
    }

    // MARK: - Warnings

    private nonisolated(unsafe) static var _warningCount: Int = 0

    /// Number of warnings actually emitted, after rate limiting. Intended for tests.
    public static var warningCount: Int {
        self.lock.perform { self._warningCount }
    }

    /// Resets everything mutated by measurement — statistics, rate-limit windows, warning count.
    /// Configuration (`subsystem`, thresholds, `onEvent`, `filter`) is left untouched.
    public static func reset() {
        self.lock.perform {
            self.statistics.removeAll()
            self.lastWarned.removeAll()
            self.warningCounts.removeAll()
            self._warningCount = 0
        }
    }

    private static func warn(
        stage: Stage,
        subject: String,
        reactable: String,
        name: String,
        duration: TimeInterval,
        threshold: TimeInterval
    ) {
        let key = StatKey(reactable: reactable, stage: stage, name: name)
        let now = self.timestamp()
        let shouldWarn: Bool = self.lock.perform {
            if let last = self.lastWarned[key], self.elapsed(since: last) < self._warningInterval {
                return false
            }
            self.lastWarned[key] = now
            self._warningCount += 1
            self.warningCounts[key, default: 0] += 1
            return true
        }
        guard shouldWarn else { return }

        // `privacy: .public` matters: a non-literal String interpolation is redacted to <private>
        // in Console.app and sysdiagnose otherwise. Safe here — this file only exists in DEBUG.
        self.logger.warning(
            """
            Slow \(stage.rawValue, privacy: .public): \(subject, privacy: .public) \
            took \(self.millisText(duration), privacy: .public) \
            (threshold \(self.millisText(threshold), privacy: .public))
            """
        )
    }

    // MARK: - Formatting

    private static func subjectText<Action: Sendable>(
        options: Options<Action>,
        reactable: String,
        name: String
    ) -> String {
        guard let label = options.label else { return "\(reactable) \(name)" }
        return "\(label).\(reactable) \(name)"
    }

    public static func millisText(_ value: TimeInterval) -> String {
        String(format: "%.1fms", value * 1000)
    }

    // MARK: - Effect lifetime bookkeeping

    /// Carries the start timestamp and signpost interval between the `handleEvents` closures, and
    /// makes sure a completion racing a cancellation only ends the interval once.
    private final class EffectTracker: @unchecked Sendable {
        private let lock = NSLock()
        private var _start: UInt64?
        private var _interval: OSSignpostIntervalState?
        private var _ended = false

        var start: UInt64? {
            get { self.lock.perform { self._start } }
            set { self.lock.perform { self._start = newValue } }
        }

        var interval: OSSignpostIntervalState? {
            get { self.lock.perform { self._interval } }
            set { self.lock.perform { self._interval = newValue } }
        }

        /// Returns the start timestamp exactly once; `nil` on any later call.
        func finish() -> UInt64? {
            self.lock.perform {
                guard !self._ended, let start = self._start else { return nil }
                self._ended = true
                return start
            }
        }

        func takeInterval() -> OSSignpostIntervalState? {
            self.lock.perform {
                let interval = self._interval
                self._interval = nil
                return interval
            }
        }
    }
    #endif
}

#if DEBUG
private extension ReactableInstrument.Stage {
    var signpostName: StaticString {
        switch self {
        case .queue: return "Queue"
        case .mutate: return "Mutate"
        case .effect: return "Effect"
        case .reduce: return "Reduce"
        }
    }

    func event(reactable: String, name: String, duration: TimeInterval) -> ReactableInstrument.Event {
        switch self {
        case .queue: return .queueLatency(reactable: reactable, action: name, duration: duration)
        case .mutate: return .mutate(reactable: reactable, action: name, duration: duration)
        case .effect: return .effect(reactable: reactable, action: name, duration: duration)
        case .reduce: return .reduce(reactable: reactable, mutation: name, duration: duration)
        }
    }
}
#endif
