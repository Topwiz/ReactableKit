//
//  SharedStateChildReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/29/25.
//

import Foundation
import ReactableKit
import Combine

final class SharedStateChildReactable: Reactable, ObservableEvent {
    
    enum Action {
        case sharedStateUpdated(SharedStateReactable.SharedState)
        case change
        case parentAction(Int)
    }
    
    struct Drawable: Hashable {
        var username: String = ""
    }
    
    struct State: PathState {
        @Shared(.file()) var sharedState = SharedStateReactable.SharedState()
        @ViewState var name: String = ""
        var index: Int = 0
    }
    
    enum Mutation {
        case setSharedName(String)
        case setName(String)
    }
    
    var initialState: State = State()
    var cancelTask = PassthroughSubject<CancelTask, Never>()
    
    enum CancelTask {
        case test
    }
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .change:
            self.cancelTask.send(.test)
            return .concat([
                .empty().delay(for: 3, scheduler: queue),
                .just(.setSharedName(randomString(length: 5)))
            ])
            .takeUntil(self.cancelTask.filter { $0 == .test }.eraseToAnyPublisher())
            
        case let .sharedStateUpdated(value):
            return .just(.setName(value.username))
            
        case .parentAction:
            return .empty()
        }
    }
    
    func reduce(state: inout State, mutate: Mutation) {
        switch mutate {
        case let .setName(name):
            state.name = name
            
        case let .setSharedName(name):
            state.sharedState.username = name
        }
    }
    
    func transformAction() -> AnyPublisher<Action, Never> {
        return .merge([
            self.currentState.$sharedState.publisher
                .map(Action.sharedStateUpdated)
                .eraseToAnyPublisher()
        ])
    }

}
