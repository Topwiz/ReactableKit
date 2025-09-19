//
//  NavigationStackReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import ReactableKit
import SwiftUI

@MainActor
final class NavigationStackReactable: Reactable {
   
    enum Action {
        case pushCounter
        case pushAsyncStressTest
        case pushCancellableExample
    }
    
    struct State {
        @ViewState var path: ReactablePath = .init()
    }
    
    enum Mutation {
        case push(any PathState)
    }
    
    var initialState: State = .init()
    
    func mutate(action: Action, state: State, send: @escaping MutationSender<Mutation>) async {
        switch action {
        case .pushCounter:
            await send(.push(AsyncCounterReactable()))
        case .pushAsyncStressTest:
            await send(.push(AsyncStressTestReactable()))
        case .pushCancellableExample:
            await send(.push(CancellableReactable()))
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .push(_state):
            state.path.append(_state)
        }
    }

}
