//
//  NavigationStackReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import ReactableKit
import SwiftUI
import Combine

final class NavigationStackReactable: Reactable {
   
    enum Action {
        case pushCounter
    }
    
    struct State {
        @ViewState var path: ReactablePath = .init()
        var counterReactable = CounterReactable()
    }
    
    enum Mutation {
        case push(any PathState)
    }
    
    var initialState: State = .init()
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .pushCounter:
            return .just(.push(CounterReactable()))
        }
    }
    
    func reduce(state: inout State, mutate: Mutation) {
        switch mutate {
        case let .push(_state):
            state.path.append(_state)
        }
    }

}
