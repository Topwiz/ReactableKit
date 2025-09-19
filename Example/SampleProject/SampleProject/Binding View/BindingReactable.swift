//
//  BindingReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/26/25.
//

import Foundation
import ReactableKit

@MainActor
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
    
    func mutate(action: Action, state: State, send: @escaping MutationSender<Mutation>) async {
        switch action {
        case .isOnChanged:
            break  // No mutation needed
            
        case .emitTest:
            await send(.emitTest)
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case .emitTest:
            state.emitTest = state.emitTest
        }
    }

}

