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

    final class MockReactable: Reactable {
        enum Action {
            case increment
            case decrement
            case multipleIncrement(Int)
            case multipleIncrementWithMainActor(Int)
        }

        struct State: Equatable, Sendable {
            var count: Int
            var mutationCount: Int = 0
        }

        enum Mutation {
            case setCount(Int)
            case incrementMutationCount
        }

        var initialState: State = State(count: 0)

        func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
            switch action {
            case .increment:
                return .run { [currentState = self.currentState] send in
                    send(.setCount(currentState.count + 1))
                }
                
            case .decrement:
                return .just(.setCount(self.currentState.count - 1))
                
            case .multipleIncrement(let times):
                return .run { [currentState = self.currentState] send in
                    for i in 1...times {
                        send(.setCount(currentState.count + i))
                        send(.incrementMutationCount)
                    }
                }
                
            case .multipleIncrementWithMainActor(let times):
                return .run { @MainActor [currentState = self.currentState] send in
                    for i in 1...times {
                        send(.setCount(currentState.count + i))
                        send(.incrementMutationCount)
                    }
                }
            }
        }

        func reduce(state: inout State, mutation: Mutation) {
            switch mutation {
            case let .setCount(value):
                state.count = value
            case .incrementMutationCount:
                state.mutationCount += 1
            }
        }

        func registerTransform() { }
    }

    // Test to verify the initial state of the reactable.
    @Test
    func testInitialState() {
        let reactable = MockReactable()
        let stub = Stub(reactable)
        #expect(stub.currentState.count == 0, "Initial state should be 0")
    }

    // Test to verify the increment action updates the state correctly.
    @Test
    func testIncrementAction() async {
        let reactable = MockReactable()
        let stub = Stub(reactable)
        let newState = await stub.action(.increment)
        #expect(newState.count == 1, "State count should be incremented to 1")
    }

    // Test to verify the decrement action updates the state correctly.
    @Test
    func testDecrementAction() async {
        let reactable = MockReactable()
        let stub = Stub(reactable)
        await stub.setState(MockReactable.State(count: 1))
        let newState = await stub.action(.decrement)
        #expect(newState.count == 0, "State count should be decremented to 0")
    }

    // Test to verify the state is published correctly.
    @Test
    func testPublisher() async {
        let reactable = MockReactable()
        let stub = Stub(reactable)
        var receivedState: MockReactable.State?

        let cancellable = reactable.state.sink { state in
            receivedState = state
        }

        let _ = await stub.action(.increment)
        let _ = await stub.action(.increment)
        
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        #expect(receivedState?.count == 2, "Published state count should be 2")
        cancellable.cancel()
    }
    
    // Test to verify multiple mutations work correctly without @MainActor
    @Test
    func testMultipleIncrementWithoutMainActor() async {
        let reactable = MockReactable()
        let stub = Stub(reactable)
        
        let finalState = await stub.action(.multipleIncrement(3))
        
        #expect(finalState.mutationCount == 3, "Mutation count should be 3 (one incrementMutationCount per iteration)")
        #expect(finalState.count == 3, "Final count should be 3 (last setCount value)")
    }
    
    // Test to verify @MainActor send works correctly after fix
    @Test
    func testMultipleIncrementWithMainActorWorks() async {
        let reactable = MockReactable()
        let stub = Stub(reactable)
        
        let finalState = await stub.action(.multipleIncrementWithMainActor(3))
        
        print("Final state with @MainActor: count=\(finalState.count), mutationCount=\(finalState.mutationCount)")
        
        #expect(finalState.mutationCount == 3, "@MainActor send should work correctly: mutationCount should be 3")
        #expect(finalState.count == 3, "@MainActor send should work correctly: count should be 3")
    }
}
