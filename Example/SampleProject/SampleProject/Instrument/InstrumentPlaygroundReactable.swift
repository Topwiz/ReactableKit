//
//  InstrumentPlaygroundReactable.swift
//  ExmapleApp
//
//  A deliberately slow Reactable used to demonstrate ReactableInstrument.
//
//  Each action burns a configurable amount of time in a different stage of the cycle, so the
//  warning can be made to appear and disappear by moving one slider. `burst` and `flood` push the
//  main queue into a backlog, which is the failure the queue-latency measurement exists to catch.
//

#if DEBUG
import Combine
import Foundation
import ReactableKit

final class InstrumentPlaygroundReactable: Reactable, @unchecked Sendable {

    enum Action {
        /// Baseline. Costs nothing and must never warn.
        case fastTick
        /// Blocks while the mutation publisher is being built.
        case slowMutate
        /// Blocks while the mutation is applied to the state.
        case slowReduce
        /// Returns a publisher that stays alive for a while without blocking.
        case slowEffect
        /// Enqueues `burstSize` slow actions at once to build a main-queue backlog.
        case burst
        case startFlood
        case stopFlood
        case setWorkMilliseconds(Double)
        case setBurstSize(Int)
        case reset
    }

    enum Mutation {
        case increaseTick
        /// Applied by a `reduce` that blocks first.
        case increaseTickSlowly
        case setWorkMilliseconds(Double)
        case setBurstSize(Int)
        case setFlooding(Bool)
        case resetCounters
    }

    struct State {
        @ViewState var tickCount: Int = 0
        @ViewState var workMilliseconds: Double = 200
        @ViewState var burstSize: Int = 100
        @ViewState var isFlooding: Bool = false
    }

    let initialState = State()

    /// Opting in is all it takes — everything else is configured globally on `ReactableInstrument`.
    var instrumentation: ReactableInstrument.Options? { .init(label: "playground") }

    /// Drives flood mode. Actions pushed here go through `transformAction()`, so they are stamped
    /// and measured exactly like an action sent from the UI.
    private let floodTick = PassthroughSubject<Action, Never>()
    private var floodCancellable: AnyCancellable?

    func transformAction() -> AnyPublisher<Action, Never> {
        self.floodTick.eraseToAnyPublisher()
    }

    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .fastTick:
            return .just(.increaseTick)

        case .slowMutate:
            // Blocking here is measured as the Mutate stage.
            Thread.sleep(forTimeInterval: self.workSeconds)
            return .just(.increaseTick)

        case .slowReduce:
            return .just(.increaseTickSlowly)

        case .slowEffect:
            // Not blocking, but the publisher stays alive — visible as a long Effect interval.
            return .run { [workSeconds = self.workSeconds] send in
                try await Task.sleep(nanoseconds: UInt64(workSeconds * 1_000_000_000))
                send(.increaseTick)
            }

        case .burst:
            // Every one of these lands on the main queue at once. Each reduce then blocks, so the
            // last action waits roughly burstSize x workMilliseconds before it is even started —
            // a backlog that per-stage durations alone would never reveal.
            for _ in 0..<self.currentState.burstSize {
                self.action(.slowReduce)
            }
            return .empty()

        case .startFlood:
            self.floodCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.floodTick.send(.slowReduce)
                }
            return .just(.setFlooding(true))

        case .stopFlood:
            self.floodCancellable?.cancel()
            self.floodCancellable = nil
            return .just(.setFlooding(false))

        case let .setWorkMilliseconds(value):
            return .just(.setWorkMilliseconds(value))

        case let .setBurstSize(value):
            return .just(.setBurstSize(value))

        case .reset:
            return .just(.resetCounters)
        }
    }

    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case .increaseTick:
            state.tickCount += 1

        case .increaseTickSlowly:
            // Blocking here is measured as the Reduce stage, and it blocks the main queue for
            // everything queued behind it.
            Thread.sleep(forTimeInterval: state.workMilliseconds / 1000)
            state.tickCount += 1

        case let .setWorkMilliseconds(value):
            state.workMilliseconds = value

        case let .setBurstSize(value):
            state.burstSize = value

        case let .setFlooding(value):
            state.isFlooding = value

        case .resetCounters:
            state.tickCount = 0
        }
    }

    private var workSeconds: TimeInterval {
        self.currentState.workMilliseconds / 1000
    }
}
#endif
