//
//  SharedStateReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/28/25.
//

import Foundation
import ReactableKit
import Combine

@MainActor
final class SharedStateReactable: Reactable, PathState {
    
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
    
    init(state: State = .init()) {
        self.initialState = state
    }
    
    func mutate(action: Action, state: State, send: @escaping MutationSender<Mutation>) async {
        switch action {
        case .removeAllData,
                .changeData:
            await send(.bypass(action))
            
        case let .childAction(action):
            print("childAction state: \(action.state)")
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
    
    func transformAction() -> AsyncStream<Action>? {
        return AsyncStream { continuation in
            Task {
                for await result in self.state.childReactable.observe() {
                    if case .change = result.action {
                        continuation.yield(.childAction(result))
                    }
                }
            }
        }
    }

}

func randomString(length: Int) -> String {
    let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map { _ in characters.randomElement()! })
}
