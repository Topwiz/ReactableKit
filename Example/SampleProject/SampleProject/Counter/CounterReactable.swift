//
//  CounterReactable.swift
//  ReactableExmaple
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import ReactableKit
import Combine

final class CounterReactable: Reactable, PathState {
    
    enum Action {
        case increase
        case decrease
        case multiply(Int)
    }
    
    struct State {
        @ViewState var count: Int = 1
        @ViewState(ignoreEquality: true) var count1: Int = 1
    }
    
    enum Mutation {
        case setCount(Int)
    }
    
    var initialState: State
    
    init(state: State = .init()) {
        self.initialState = state
    }
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .increase:
            return .just(.setCount(self.currentState.count + 1))
            
        case .decrease:
            return .just(.setCount(self.currentState.count - 1))
            
        case let .multiply(value):
            return .just(.setCount(self.currentState.count * value))
        }
    }
    
    func reduce(state: inout State, mutate: Mutation) {
        switch mutate {
        case let .setCount(value):
            state.count = value
        }
    }
    
    func transformAction() -> AnyPublisher<Action, Never> {
        let customAction = PassthroughSubject<Action, Never>()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            customAction.send(.increase)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            customAction.send(.multiply(5))
        }
        
        return .merge([
            customAction.eraseToAnyPublisher(),
        ])
    }
}
