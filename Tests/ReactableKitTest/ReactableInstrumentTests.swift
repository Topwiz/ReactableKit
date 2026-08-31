//
//  ReactableInstrumentTests.swift
//  ReactableKit
//

#if DEBUG
import Combine
import Foundation
import Testing
@testable import ReactableKit

/// Every test here mutates process-global instrument state, so the suite is serialized and each
/// test restores the defaults before it runs.
///
/// - Note: These tests assume the `REACTABLE_INSTRUMENT` environment variable is not set. It is
///   read once per process and would turn instrumentation on for every Reactable.
@Suite(.serialized)
struct ReactableInstrumentTests {

    // MARK: - Fixtures

    /// Collects everything `ReactableInstrument.onEvent` delivers.
    final class EventRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [ReactableInstrument.Event] = []

        var events: [ReactableInstrument.Event] { self.lock.perform { self.storage } }

        func install() {
            ReactableInstrument.onEvent = { [weak self] event in
                guard let self else { return }
                self.lock.perform { self.storage.append(event) }
            }
        }

        func events(for stage: ReactableInstrument.Stage) -> [ReactableInstrument.Event] {
            self.events.filter { $0.stage == stage }
        }

        func names(for stage: ReactableInstrument.Stage) -> [String] {
            self.events(for: stage).map(\.name)
        }
    }

    /// Not instrumented — used to prove the default is off.
    final class PlainReactable: Reactable {
        enum Action { case bump }
        enum Mutation { case increase }
        struct State: Equatable, Sendable { var count: Int = 0 }

        var initialState = State()

        func mutate(action: Action) -> AnyPublisher<Mutation, Never> { .just(.increase) }
        func reduce(state: inout State, mutation: Mutation) { state.count += 1 }
    }

    /// Opts in, and can be told to burn a fixed amount of time inside `reduce`.
    final class InstrumentedReactable: Reactable, @unchecked Sendable {
        enum Action { case bump, slowBump }
        enum Mutation { case increase, increaseSlowly }
        struct State: Equatable, Sendable { var count: Int = 0 }

        var initialState = State()
        var reduceWorkSeconds: TimeInterval = 0

        var instrumentation: ReactableInstrument.Options? { .default }

        func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
            switch action {
            case .bump: return .just(.increase)
            case .slowBump: return .just(.increaseSlowly)
            }
        }

        func reduce(state: inout State, mutation: Mutation) {
            if case .increaseSlowly = mutation, self.reduceWorkSeconds > 0 {
                Thread.sleep(forTimeInterval: self.reduceWorkSeconds)
            }
            state.count += 1
        }
    }

    /// Restores every global the instrument owns. Configuration is global state; leaving it dirty
    /// would leak into the next test even with serialized execution.
    private func resetInstrument() {
        ReactableInstrument.onEvent = nil
        ReactableInstrument.filter = nil
        ReactableInstrument.enabledByDefault = false
        ReactableInstrument.statisticsEnabled = true
        ReactableInstrument.warningThreshold = 0.05
        ReactableInstrument.warningInterval = 1.0
        ReactableInstrument.reset()
    }

    // MARK: - Enablement

    @Test
    func testNotInstrumentedByDefault() async {
        self.resetInstrument()
        let recorder = EventRecorder()
        recorder.install()

        let reactable = PlainReactable()
        reactable.initialize()
        await reactable.asyncAction(.bump)

        #expect(recorder.events.isEmpty, "A Reactable that never opts in must not be measured")
        self.resetInstrument()
    }

    @Test
    func testOptInProducesMutateAndReduceEvents() async {
        self.resetInstrument()
        let recorder = EventRecorder()
        recorder.install()

        let reactable = InstrumentedReactable()
        reactable.initialize()
        await reactable.asyncAction(.bump)

        #expect(recorder.names(for: .mutate) == ["bump"], "mutate should be measured with its case name")
        #expect(recorder.names(for: .reduce) == ["increase"], "reduce should be measured with its case name")
        #expect(recorder.events(for: .effect).count == 1, "the mutation publisher lifetime should be measured")
        self.resetInstrument()
    }

    @Test
    func testEnabledByDefaultInstrumentsEverything() async {
        self.resetInstrument()
        let recorder = EventRecorder()
        recorder.install()
        ReactableInstrument.enabledByDefault = true

        let reactable = PlainReactable()
        reactable.initialize()
        await reactable.asyncAction(.bump)

        #expect(!recorder.events.isEmpty, "The global switch should measure Reactables that never opted in")
        self.resetInstrument()
    }

    @Test
    func testFilterSelectsByTypeName() async {
        self.resetInstrument()
        let recorder = EventRecorder()
        recorder.install()
        ReactableInstrument.filter = { $0.contains("Plain") }

        let matching = PlainReactable()
        matching.initialize()
        await matching.asyncAction(.bump)

        #expect(!recorder.events.isEmpty, "A type name matching the filter should be measured")
        self.resetInstrument()
    }

    @Test
    func testFilterNarrowsTheGlobalSwitch() async {
        self.resetInstrument()
        let recorder = EventRecorder()
        recorder.install()
        // A filter must decide on its own: a non-matching name stays un-instrumented even though
        // the global switch is on, otherwise the filter would widen rather than narrow.
        ReactableInstrument.enabledByDefault = true
        ReactableInstrument.filter = { $0.contains("SomethingElse") }

        let reactable = PlainReactable()
        reactable.initialize()
        await reactable.asyncAction(.bump)

        #expect(recorder.events.isEmpty, "A filter should narrow enabledByDefault, not be ignored by it")
        self.resetInstrument()
    }

    @Test
    func testFilterSkipsUnmatchedTypeName() async {
        self.resetInstrument()
        let recorder = EventRecorder()
        recorder.install()
        ReactableInstrument.filter = { $0.contains("SomethingElse") }

        let reactable = PlainReactable()
        reactable.initialize()
        await reactable.asyncAction(.bump)

        #expect(recorder.events.isEmpty, "A type name outside the filter must not be measured")
        self.resetInstrument()
    }

    @Test
    func testStubIsNotInstrumented() async {
        self.resetInstrument()
        let recorder = EventRecorder()
        recorder.install()

        // Stub drives mutate/reduce directly *and* through the stream, so measuring it would
        // double count every sample.
        let stub = Stub(InstrumentedReactable())
        await stub.action(.bump)

        #expect(recorder.events.isEmpty, "Stub-driven cycles must not be measured")
        self.resetInstrument()
    }

    @Test
    func testStubIsNotInstrumentedWhenFlaggedAfterStreamCreation() async {
        self.resetInstrument()
        let recorder = EventRecorder()
        recorder.install()

        // A Reactable can be wrapped in a `Stub` after its stream already exists, so a stub check
        // cached at stream-creation time would keep measuring it — and `Stub` drives mutate/reduce
        // directly as well as through the stream, so every sample would be counted twice.
        //
        // Driven through `asyncAction` rather than `Stub.action` on purpose: `Stub.action` resumes
        // as soon as its own direct mutate/reduce finishes, without waiting for the stream-path
        // cycle, so asserting right after it would race the very events under test.
        let reactable = InstrumentedReactable()
        reactable.initialize()
        reactable.isStub = true
        await reactable.asyncAction(.bump)

        #expect(recorder.events.isEmpty, "Stub-driven cycles must not be measured, whenever it wraps")
        self.resetInstrument()
    }

    @Test
    func testTurningTheGlobalSwitchBackOffStopsInstrumentation() async {
        self.resetInstrument()
        let recorder = EventRecorder()
        recorder.install()
        ReactableInstrument.enabledByDefault = true
        ReactableInstrument.enabledByDefault = false

        let reactable = PlainReactable()
        reactable.initialize()
        await reactable.asyncAction(.bump)

        #expect(recorder.events.isEmpty, "Disabling the global switch should stop measurement again")
        self.resetInstrument()
    }

    // MARK: - Case names

    @Test
    func testCaseNameExtraction() {
        enum Inner { case inner }
        enum Outer {
            case flat
            case withPayload(Int)
            case nested(Inner)
        }
        struct NotAnEnum { var value = 1 }

        #expect(ReactableInstrument.caseName(of: Outer.flat) == "flat")
        #expect(ReactableInstrument.caseName(of: Outer.withPayload(42)) == "withPayload",
                "Associated values must never be dumped")
        #expect(ReactableInstrument.caseName(of: Outer.nested(.inner)) == "nested(.inner)")
        // Keyed on the type, not the value: a per-value name would mint a new statistics key for
        // every sample and hand each slow cycle a fresh rate-limit window.
        #expect(ReactableInstrument.caseName(of: NotAnEnum()) == ReactableInstrument.caseName(of: NotAnEnum(value: 99)),
                "Non-enum values must collapse to a single, bounded key")
    }

    @Test
    func testLazyNameComputesAtMostOnce() {
        let counter = Counter()
        let name = ReactableInstrument.LazyName {
            counter.increment()
            return "computed"
        }

        #expect(counter.value == 0, "The name must not be computed until something asks for it")
        #expect(name.value == "computed")
        #expect(name.value == "computed")
        #expect(counter.value == 1, "The name must be computed at most once")
    }

    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = 0
        var value: Int { self.lock.perform { self.storage } }
        func increment() { self.lock.perform { self.storage += 1 } }
    }

    // MARK: - Warnings

    @Test
    func testSlowCycleWarningIsRateLimited() async {
        self.resetInstrument()
        // A window far longer than the test can run, so the rate limit cannot roll over midway.
        ReactableInstrument.warningInterval = 60
        ReactableInstrument.warningThreshold = 0.01

        let reactable = InstrumentedReactable()
        reactable.reduceWorkSeconds = 0.03
        reactable.initialize()

        let cycles = 3
        for _ in 0..<cycles {
            await reactable.asyncAction(.slowBump)
        }

        #expect(
            ReactableInstrument.warningCount(
                reactable: "InstrumentedReactable",
                stage: .reduce,
                name: "increaseSlowly"
            ) == 1,
            "Repeated slow cycles for the same case should warn once per interval"
        )
        #expect(
            ReactableInstrument.sampleCount(
                reactable: "InstrumentedReactable",
                stage: .reduce,
                name: "increaseSlowly"
            ) == cycles,
            "Rate limiting must not drop statistics samples"
        )
        // The blocking reduce runs while the `.just` publisher is still alive, so the Effect stage
        // legitimately warns as well — a separate key with its own rate-limit window.
        #expect(ReactableInstrument.warningCount > 1, "Warnings are rate limited per stage, not globally")
        self.resetInstrument()
    }

    @Test
    func testFastCycleDoesNotWarn() async {
        self.resetInstrument()
        ReactableInstrument.warningThreshold = 1.0

        let reactable = InstrumentedReactable()
        reactable.initialize()
        await reactable.asyncAction(.bump)

        #expect(ReactableInstrument.warningCount == 0, "A cycle under the threshold must not warn")
        self.resetInstrument()
    }

    // MARK: - Statistics

    @Test
    func testReportAndReset() async {
        self.resetInstrument()

        let reactable = InstrumentedReactable()
        reactable.initialize()
        await reactable.asyncAction(.bump)

        let report = ReactableInstrument.report()
        #expect(report.contains("InstrumentedReactable"), "The report should name the measured Reactable")
        #expect(report.contains("bump"), "The report should name the measured case")

        ReactableInstrument.resetStatistics()
        #expect(
            ReactableInstrument.sampleCount(reactable: "InstrumentedReactable", stage: .mutate, name: "bump") == 0,
            "resetStatistics should clear accumulated samples"
        )
        #expect(ReactableInstrument.report().contains("no samples"))
        self.resetInstrument()
    }

    // MARK: - Queue latency

    @Test
    func testQueueLatencyIsRecorded() async {
        self.resetInstrument()
        let recorder = EventRecorder()
        recorder.install()

        let reactable = InstrumentedReactable()
        reactable.initialize()
        await reactable.asyncAction(.bump)

        let latencies = recorder.events(for: .queue)
        #expect(latencies.count == 1, "Every action should report how long it waited on the main queue")
        #expect(latencies.first.map { $0.duration >= 0 } == true)
        #expect(latencies.first?.name == "bump")
        self.resetInstrument()
    }

    /// The regression this instrument exists for: individual stages stay fast while actions pile up
    /// behind a blocked main queue. Only queue latency shows it.
    @Test
    func testQueueLatencyGrowsUnderBacklog() async {
        self.resetInstrument()
        let recorder = EventRecorder()
        recorder.install()

        let work: TimeInterval = 0.02
        let burst = 10
        let reactable = InstrumentedReactable()
        reactable.reduceWorkSeconds = work
        reactable.initialize()

        // Enqueue everything at once, then wait for the last one to finish.
        for _ in 0..<(burst - 1) {
            reactable.action(.slowBump)
        }
        await reactable.asyncAction(.slowBump)

        let latencies = recorder.events(for: .queue).map(\.duration)
        let reduceDurations = recorder.events(for: .reduce).map(\.duration)

        #expect(latencies.count == burst)
        // Asserted relative to the measured reduce cost rather than against wall-clock constants,
        // so a loaded machine slows both sides and the comparison still holds.
        let slowestReduce = reduceDurations.max() ?? 0
        let slowestLatency = latencies.max() ?? 0
        #expect(
            slowestLatency > slowestReduce * 3,
            """
            The last action waited behind the whole backlog, so queue latency must dwarf any single \
            reduce — that gap is the whole point of measuring the queue.
            """
        )
        self.resetInstrument()
    }
}
#endif
