//
//  SharedStateReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/28/25.
//

import Foundation
import ReactableKit
import Combine

final class SharedStateReactable: Reactable, PathState, @unchecked Sendable {
    
    enum Action {
        case changeData
        case removeAllData
//        case sharedStateChanged(SharedState)
        case childAction(ObservableEventResult<SharedStateChildReactable>)
    }
    
    struct Drawable: Equatable {
        var username: String = ""
        var age: Int = 0
        var isPremium: Bool = false
    }
    
    struct State {
//        @Shared(.memory) var isPremium = false
//        @Shared(.file(path: "testing/")) var sharedState = SharedState()
//        @Shared(.file(path: "testing/")) var bool = false
        @SharedViewState var drawable: Drawable = .init()
        let childReactable = SharedStateChildReactable()
    }
    
    enum Mutation {
        case bypass(Action)
        case updateDrawable
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
        case .removeAllData,
                .changeData:
            return .just(.bypass(action))
            
        case let .childAction(action):
            print("childAction state: \(action.state)")
            return .empty()
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case .bypass(.removeAllData):
            state.drawable = .init()
            
        case .bypass(.changeData):
            state.drawable.age = Int.random(in: 0...100)
            state.drawable.isPremium = Bool.random()
            
        default:
            break
        }
    }
    
    func transformAction() -> AnyPublisher<Action, Never> {
//        let globalChildEvent = SharedStateChildReactable.observe()
//            .filter { result in
//                if case .change = result.action { return true }
//                return false
//            }
//            .map(Action.childAction)
//            .eraseToAnyPublisher()
        
        // local child event
        let localChildEvent = self.currentState.childReactable.observe()
            .filter { result in
                if case .change = result.action { return true }
                return false
            }
            .map(Action.childAction)
            .eraseToAnyPublisher()
        
        
        return .merge([
            localChildEvent,
        ])
    }

}

func randomString(length: Int) -> String {
    let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map { _ in characters.randomElement()! })
}
