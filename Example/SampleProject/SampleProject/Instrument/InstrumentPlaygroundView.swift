//
//  InstrumentPlaygroundView.swift
//  ExmapleApp
//
//  Live demonstration of ReactableInstrument: make a stage slow, watch it warn, raise the
//  threshold, watch the warning go away.
//

import SwiftUI
import ReactableKit

#if DEBUG

// MARK: - Event recorder

/// Mirrors `ReactableInstrument.onEvent` into SwiftUI state.
///
/// - Important: This is a plain `ObservableObject` on purpose. Feeding instrument events back into
///   an instrumented Reactable would be an endless loop: every event would dispatch an action,
///   whose cycle would emit more events.
@MainActor
final class InstrumentEventRecorder: ObservableObject {

    struct Entry: Identifiable {
        let id = UUID()
        let stage: ReactableInstrument.Stage
        let name: String
        let duration: TimeInterval
        let isSlow: Bool
    }

    private static let capacity = 150

    @Published private(set) var entries: [Entry] = []
    @Published private(set) var maxQueueLatency: TimeInterval = 0

    /// `onEvent` and `warningThreshold` are process-wide. The playground borrows them and hands
    /// them back, so an app that installed its own reporter still has it after visiting once.
    ///
    /// `isBorrowing` guards against a repeated `onAppear` (SwiftUI may send one without an
    /// intervening `onDisappear`): snapshotting twice would capture this recorder's own closure as
    /// the "previous" one and leave it installed for the rest of the process.
    private var isBorrowing = false
    private var previousOnEvent: (@Sendable (ReactableInstrument.Event) -> Void)?
    private var previousThreshold: TimeInterval?

    func start() {
        guard !self.isBorrowing else { return }
        self.isBorrowing = true
        self.previousOnEvent = ReactableInstrument.onEvent
        self.previousThreshold = ReactableInstrument.warningThreshold
        ReactableInstrument.onEvent = { [weak self] event in
            // The instrument calls back on whichever thread ran the cycle, so hop to main.
            Task { @MainActor in self?.append(event) }
        }
    }

    func stop() {
        guard self.isBorrowing else { return }
        self.isBorrowing = false
        ReactableInstrument.onEvent = self.previousOnEvent
        if let previousThreshold = self.previousThreshold {
            ReactableInstrument.warningThreshold = previousThreshold
        }
        self.previousOnEvent = nil
        self.previousThreshold = nil
    }

    func clear() {
        self.entries.removeAll()
        self.maxQueueLatency = 0
        ReactableInstrument.reset()
    }

    private func append(_ event: ReactableInstrument.Event) {
        let entry = Entry(
            stage: event.stage,
            name: event.name,
            duration: event.duration,
            isSlow: event.duration >= ReactableInstrument.warningThreshold
        )
        self.entries.insert(entry, at: 0)
        if self.entries.count > Self.capacity {
            self.entries.removeLast(self.entries.count - Self.capacity)
        }
        if case .queueLatency = event {
            self.maxQueueLatency = max(self.maxQueueLatency, event.duration)
        }
    }
}

// MARK: - View

struct InstrumentPlaygroundView: View {

    @StateObject private var store = Store(InstrumentPlaygroundReactable())
    @StateObject private var recorder = InstrumentEventRecorder()

    @State private var thresholdMilliseconds: Double = ReactableInstrument.warningThreshold * 1000
    @State private var report: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                self.configSection
                self.warningSection
                self.stressSection
                self.logSection
                self.reportSection
                self.instrumentsFooter
            }
            .padding()
        }
        .navigationTitle("ReactableInstrument")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            self.recorder.start()
            ReactableInstrument.warningThreshold = self.thresholdMilliseconds / 1000
        }
        .onDisappear {
            self.recorder.stop()
            self.store.action(.stopFlood)
        }
    }

    // MARK: Config

    private var configSection: some View {
        Card(title: "⚙️ Configuration") {
            LabeledSlider(
                title: "Warning threshold",
                value: Binding(
                    get: { self.thresholdMilliseconds },
                    set: {
                        self.thresholdMilliseconds = $0
                        ReactableInstrument.warningThreshold = $0 / 1000
                    }
                ),
                range: 5...500,
                step: 5
            )

            LabeledSlider(
                title: "Work per action",
                value: Binding(
                    get: { self.store.state.workMilliseconds },
                    set: { self.store.action(.setWorkMilliseconds($0)) }
                ),
                range: 0...500,
                step: 5
            )

            Stepper(
                "Burst size: \(self.store.state.burstSize)",
                value: Binding(
                    get: { self.store.state.burstSize },
                    set: { self.store.action(.setBurstSize($0)) }
                ),
                in: 10...500,
                step: 10
            )
            .font(.subheadline)

            Text(self.store.state.workMilliseconds >= self.thresholdMilliseconds
                 ? "Work is above the threshold — the slow buttons will warn."
                 : "Work is below the threshold — nothing will warn. Lower the threshold or raise the work.")
                .font(.caption)
                .foregroundStyle(self.store.state.workMilliseconds >= self.thresholdMilliseconds ? .orange : .secondary)
        }
    }

    // MARK: Warnings

    private var warningSection: some View {
        Card(title: "🚨 이렇게 하면 워닝이 뜹니다") {
            Text("Tick count: \(self.store.state.tickCount)")
                .font(.subheadline.monospacedDigit())

            DemoButton(
                title: "Fast action",
                detail: "Costs nothing → never warns",
                color: .green
            ) { self.store.action(.fastTick) }

            DemoButton(
                title: "Slow mutate",
                detail: "Blocks while building the mutation → Slow mutate: …",
                color: .orange
            ) { self.store.action(.slowMutate) }

            DemoButton(
                title: "Slow reduce",
                detail: "Blocks while applying state → Slow reduce: …",
                color: .orange
            ) { self.store.action(.slowReduce) }

            DemoButton(
                title: "Long effect",
                detail: "Publisher stays alive → long Effect interval",
                color: .blue
            ) { self.store.action(.slowEffect) }

            Text("""
                 Console output looks like:
                 Slow reduce: playground.InstrumentPlaygroundReactable increaseTickSlowly \
                 took 200.3ms (threshold 50.0ms)
                 """)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Stress

    private var stressSection: some View {
        Card(title: "🔥 Stress — main queue backlog") {
            Text("Max queue latency: \(ReactableInstrument.millisText(self.recorder.maxQueueLatency))")
                .font(.headline.monospacedDigit())
                .foregroundStyle(self.recorder.maxQueueLatency >= 1 ? .red : .primary)

            Text("""
                 Every stage can look healthy while actions pile up behind a blocked main queue. \
                 Queue latency is the only measurement that shows it.
                 """)
                .font(.caption)
                .foregroundStyle(.secondary)

            DemoButton(
                title: "Burst \(self.store.state.burstSize) actions",
                detail: "≈ \(ReactableInstrument.millisText(Double(self.store.state.burstSize) * self.store.state.workMilliseconds / 1000)) of backlog",
                color: .red
            ) { self.store.action(.burst) }

            DemoButton(
                title: self.store.state.isFlooding ? "Stop flood" : "Flood @ 0.5s",
                detail: "Mirrors a location stream. Steady while work < 500ms, unbounded above it.",
                color: self.store.state.isFlooding ? .gray : .purple
            ) {
                self.store.action(self.store.state.isFlooding ? .stopFlood : .startFlood)
            }
        }
    }

    // MARK: Log

    private var logSection: some View {
        Card(title: "📜 Live events (\(self.recorder.entries.count))") {
            if self.recorder.entries.isEmpty {
                Text("No events yet — tap one of the buttons above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(self.recorder.entries.prefix(40)) { entry in
                        HStack {
                            Text(entry.stage.rawValue)
                                .font(.caption2.monospaced())
                                .frame(width: 52, alignment: .leading)
                                .foregroundStyle(.secondary)
                            Text(entry.name)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                            Spacer()
                            Text(ReactableInstrument.millisText(entry.duration))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(entry.isSlow ? .red : .primary)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            Button("Clear") { self.recorder.clear() }
                .font(.caption)
        }
    }

    // MARK: Report

    private var reportSection: some View {
        Card(title: "📊 Aggregated report") {
            HStack {
                Button("Refresh") { self.report = ReactableInstrument.report() }
                Button("Reset stats") {
                    ReactableInstrument.resetStatistics()
                    self.report = ReactableInstrument.report()
                }
            }
            .font(.caption)

            if !self.report.isEmpty {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(self.report)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var instrumentsFooter: some View {
        Text("""
             Instruments: Edit Scheme ▸ Profile ▸ Build Configuration = Debug, then ⌘I, \
             add the os_signpost instrument and look for subsystem \
             "\(ReactableInstrument.subsystem)" / category "Reactable".
             """)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Small building blocks

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(self.title).font(.headline)
            self.content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(self.title): \(Int(self.value))ms")
                .font(.subheadline.monospacedDigit())
            Slider(value: self.$value, in: self.range, step: self.step)
        }
    }
}

private struct DemoButton: View {
    let title: String
    let detail: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(self.title).font(.subheadline.bold())
                Text(self.detail).font(.caption2).opacity(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(self.color.opacity(0.85)))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { InstrumentPlaygroundView() }
}

#else

/// Release builds compile the instrument out entirely, so there is nothing to demonstrate.
struct InstrumentPlaygroundView: View {
    var body: some View {
        Text("ReactableInstrument is compiled out of release builds.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding()
    }
}

#endif
