//
//  ForEachReactable.swift
//  ExmapleApp
//
//  Created by david-rx-nt-2025-01 on 2/13/25.
//

import Foundation
import ReactableKit

final class ForEachReactable: Reactable, PathState {
    
    enum Action {
        case changeLeft
        case changeRight
    }
    
    enum Mutation {
        case bypass(Action)
    }
    
    struct State {
        @ViewState var leftList: [Test] = [.init(index: 0), .init(index: 1), .init(index: 2), .init(index: 3)]
        @ViewState var rightList: [Test] = [.init(index: 0), .init(index: 1), .init(index: 2), .init(index: 3)]
    }
    
    struct Test: Identifiable, Equatable {
        var id = UUID()
        var index: Int
        var toggle: Bool = false
    }
    
    let initialState: State = State()
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        return .just(.bypass(action))
    }
    
    func reduce(state: inout State, mutate: Mutation) {
        switch mutate {
        case .bypass(.changeLeft):
            state.leftList[Int.random(in: 0..<state.leftList.count)] = .init(index: Int.random(in: 0..<100))
            
        case .bypass(.changeRight):
            state.rightList[Int.random(in: 0..<state.rightList.count)] = .init(index: Int.random(in: 0..<100))
        }
    }
}

