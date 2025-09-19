//
//  ManagerSampleReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/29/25.
//

import Foundation
import ReactableKit

@MainActor
final class ManagerSampleReactable: Reactable {
    
    static var shared: ManagerSampleReactable = ManagerSampleReactable()
    
    enum Action {
        case test
    }
    
    enum Mutation {
        case setTest(String)
    }
    
    struct State {
        var test: String = ""
    }
    
    var initialState: State = State()
    
    init() {
        self.initialize()
    }
    
    func mutate(action: Action, state: State, send: @escaping MutationSender<Mutation>) async {
        switch action {
        case .test:
            await send(.setTest(randomString(length: 10)))
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .setTest(value):
            state.test = value
        }
    }
    
    func transformAction() -> AsyncStream<Action>? {
        nil
    }

}

@MainActor
final class ManagerSampleContainer {
    static var shared: ManagerSampleContainer = ManagerSampleContainer()
    
    func updateAsyncState() {
        Task { @MainActor in
            await ManagerSampleReactable.shared.action(.test)
        }
    }
}
