//
//  ManagerSampleReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/29/25.
//

import Foundation
import ReactableKit

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
        self.registerTransform()
    }
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .test:
            return .just(.setTest(randomString(length: 10)))
        }
    }
    
    func reduce(state: inout State, mutate: Mutation) {
        switch mutate {
        case let .setTest(value):
            state.test = value
        }
    }
    
    func transformAction() -> AnyPublisher<Action, Never> {
        .empty()
    }

}

final class ManagerSampleContainer {
    static var shared: ManagerSampleContainer = ManagerSampleContainer()
    
    func updateAsyncState() {
        Task {
            let state = try await ManagerSampleReactable.shared.action(.test)
            print("update state 1 \(state)")
        }
    }
    
    func updateState() {
        ManagerSampleReactable.shared.action(.test)
        
        let action = ManagerSampleReactable.shared.actionPublish(.test)
            .sink { state in
                
            }
        
        ManagerSampleReactable.shared.action(.test) { state in
            
        }

    }
}
