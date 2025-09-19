//
//  SharedStateChildReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/29/25.
//

import Foundation
import ReactableKit

@MainActor
final class SharedStateChildReactable: Reactable, PathState, ObservableEvent {
    
    enum Action {
        case sharedStateUpdated(SharedStateReactable.Drawable)
        case change
    }
    
    struct Drawable: Equatable {
        var username: String = ""
    }
    
    struct State {
        @Shared var sharedState = SharedStateReactable.Drawable()
        @ViewState var name: String = ""
        var index: Int = 0
    }
    
    enum Mutation {
        case setSharedName(String)
        case setName(String)
    }
    
    var initialState: State = State()
    
    func mutate(action: Action, state: State, send: @escaping MutationSender<Mutation>) async {
        switch action {
        case .change:
            await send(.setSharedName(randomString(length: 5)))
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await send(.setSharedName(randomString(length: 5)))

        case let .sharedStateUpdated(value):
            await send(.setName(value.username))
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .setName(name):
            state.name = name
            
        case let .setSharedName(name):
            state.sharedState.username = name
        }
    }
    
    func transformAction() -> AsyncStream<Action>? {
        return AsyncStream { continuation in
            Task {
                for await value in self.state.$sharedState.publisher.values {
                    continuation.yield(.sharedStateUpdated(value))
                }
            }
        }
    }

}
