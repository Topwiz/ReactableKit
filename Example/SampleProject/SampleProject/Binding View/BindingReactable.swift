//
//  BindingReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/26/25.
//

import Foundation
import ReactableKit
import Combine

final class BindingReactable: Reactable, PathState {
    
    enum Action {
        case isOnChanged
        case emitTest
    }
    
    struct State {
        @ViewState var isOn1: Bool = false
        @ViewState var isOn2: Bool = false
        @ViewState var slider: Float = 0
        @Emit var emitTest: Bool = true
    }
    
    enum Mutation {
        case emitTest
    }
    
    var initialState: State
    
    init(state: State = .init()) {
        self.initialState = state
    }
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .isOnChanged:
            print("isOnChanged 1 changed: \(self.currentState.isOn1)")
            return .empty()
            
        case .emitTest:
            return .just(.emitTest)
        }
    }
    
    func reduce(state: inout State, mutate: Mutation) {
        switch mutate {
        case .emitTest:
            state.emitTest = state.emitTest
        }
    }

}

