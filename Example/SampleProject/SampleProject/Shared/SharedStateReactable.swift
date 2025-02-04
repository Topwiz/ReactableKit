//
//  SharedStateReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/28/25.
//

import Foundation
import ReactableKit
import Combine

final class SharedStateReactable: Reactable {
    
    enum Action {
        case changeData
        case removeAllData
        case sharedStateChanged(SharedState)
        case childAction(SharedStateChildReactable.Action)
    }
    
    struct Drawable: Equatable, Hashable {
        var username: String = ""
        var age: Int = 0
        var isPremium: Bool = false
    }
    
    struct SharedState: Codable, Equatable, Hashable {
        var username: String = ""
        var age: Int = 0
        var isPremium: Bool = false
    }
    
    struct State: PathState {
//        @Shared(.userDefaults()) var username = "Guest"
//        @Shared(.file()) var age = 0
//        @Shared(.memory) var isPremium = false
        @Shared(.file()) var sharedState = SharedState()
        
        @ViewState var drawable: Drawable = .init()
    }
    
    enum Mutation {
        case updateDrawable
        case removeSharedState
        case setSharedState(SharedState)
    }
    
    var initialState: State
    var cancelTask = PassthroughSubject<CancelTask, Never>()
    
    enum CancelTask {
        case test
    }
    
    init(state: State = .init()) {
        self.initialState = state
    }
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case let .sharedStateChanged(value):
            return .just(.updateDrawable)
            
        case .removeAllData:
            return .just(.removeSharedState)
            
        case .changeData:
            var newValue = currentState.sharedState
            newValue.age = Int.random(in: 0...100)
            newValue.isPremium = Bool.random()
            return .concat([
                .just(.setSharedState(newValue)),
                .just(.updateDrawable),
            ])
            
        case let .childAction(action):
            print("childAction: \(action)")
            return .empty()
        }
    }
    
    func reduce(state: inout State, mutate: Mutation) {
        switch mutate {
        case .removeSharedState:
            state.$sharedState.remove()
            state.sharedState = SharedState()
            
        case let .setSharedState(value):
            state.sharedState = value
            
        case .updateDrawable:
            state.drawable.age = state.sharedState.age
            state.drawable.isPremium = state.sharedState.isPremium
        }
    }
    
    func transformAction() -> AnyPublisher<Action, Never> {
        let childEvent = SharedStateChildReactable.Action.observe()
            .filter {
                if case .parentAction = $0 { return true }
                return false
            }
            .map(Action.childAction)
            .eraseToAnyPublisher()
        
        return .merge([
            self.currentState.$sharedState.publisher
                .map(Action.sharedStateChanged)
                .eraseToAnyPublisher(),
            childEvent,
        ])
    }

}

func randomString(length: Int) -> String {
    let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map { _ in characters.randomElement()! })
}
