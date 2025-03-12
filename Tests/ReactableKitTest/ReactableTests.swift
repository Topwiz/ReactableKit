//
//  ReactableTests.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 3/13/25.
//

import Testing
import Combine
@testable import ReactableKit

struct ReactableTests {

    class MockReactable: Reactable {
        enum Action {
            case increment
            case decrement
        }

        struct State: Equatable, Sendable {
            var count: Int
        }

        enum Mutation {
            case setCount(Int)
        }

        var initialState: State = State(count: 0)

        func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
            switch action {
            case .increment:
                return .just(.setCount(self.currentState.count + 1))
            case .decrement:
                return .just(.setCount(self.currentState.count - 1))
            }
        }

        func reduce(state: inout State, mutate: Mutation) {
            switch mutate {
            case let .setCount(value):
                state.count = value
            }
        }

        func registerTransform() { }
    }

    // Test to verify the initial state of the reactable.
    @Test
    func testInitialState() {
        let reactable = MockReactable()
        #expect(reactable.currentState.count == 0, "Initial state should be 0")
    }

    // Test to verify the increment action updates the state correctly.
    @Test
    func testIncrementAction() async {
        let reactable = MockReactable()
        let newState = await reactable.action(.increment)
        #expect(newState.count == 1, "State count should be incremented to 1")
    }

    // Test to verify the decrement action updates the state correctly.
    @Test
    func testDecrementAction() async {
        let reactable = MockReactable()
        reactable.setState(MockReactable.State(count: 1))
        let newState = await reactable.action(.decrement)
        #expect(newState.count == 0, "State count should be decremented to 0")
    }

    // Test to verify the state is published correctly.
    @Test
    func testPublisher() async {
        let reactable = MockReactable()
        var receivedState: MockReactable.State?

        let cancellable = reactable.state.sink { state in
            receivedState = state
        }

        reactable.setState(MockReactable.State(count: 2))

        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        #expect(receivedState?.count == 2, "Published state count should be 2")
        cancellable.cancel()
    }
}
