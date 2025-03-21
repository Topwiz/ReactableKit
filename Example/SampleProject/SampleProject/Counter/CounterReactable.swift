//
//  CounterReactable.swift
//  ReactableExmaple
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import ReactableKit
import Combine
import DependencyInjectableKit

final class CounterReactable: Reactable, PathState {
    
    enum Action {
        case increase
        case decrease
    }
    
    struct State {
        @ViewState var count: Int = 1
        @ViewState(ignoreEquality: true) var count1: Int = 1
    }
    
    enum Mutation {
        case setCount(Int)
    }
    
    enum CancelTask {
        case increase
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
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .setCount(value):
            state.count = value
        }
    }
}
