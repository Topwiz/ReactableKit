//
//  CounterReactable.swift
//  ReactableExmaple
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import ReactableKit
import Combine

extension CounterReactable: @unchecked Sendable { }

final class CounterReactable: Reactable, PathState {
    
    enum Action {
        case increase
        case decrease
        case multiply(Int)
    }
    
    struct State {
        @ViewState var count: Int = 1
        @ViewState(ignoreEquality: true) var count1: Int = 1
    }
    
    enum Mutation {
        case setCount(Int)
        case setCount1(Int)
    }
    
    enum CancelTask {
        case increase
    }
    
    var cancelTask = PassthroughSubject<CancelTask, Never>()
    var initialState: State
    
    init(state: State = .init()) {
        self.initialState = state
    }
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .increase:
            self.cancelTask.send(.increase)
            return .concat([
                .run { [weak self] send in
                    guard let self else { return }
                    // 1) Mutation
                    await send(.setCount(10))
                    print("1 Mutation")
                    
                    // 2) API
                    let userInfo = await self.fetchUserData()
                    print("2 API: \(userInfo)")
                    
                    guard !Task.isCancelled else {
                        print("3 Task is cancelled")
                        return
                    }
                    
                    // 3) Second Mutation
                    await send(.setCount(20))
                    print("4 Second Mutation")
                    
                    // 4) Addtional API
                    let otherData = await self.fetchOtherData()
                    print("5 Addtional API: \(otherData)")
                },
                .just(.setCount(30)),
            ])
            .takeUntil(self.cancelTask.filter { $0 == .increase }.eraseToAnyPublisher())
            
            
        case .decrease:
            return .just(.setCount1(self.currentState.count1 - 1))
            
        case let .multiply(value):
            return .just(.setCount(self.currentState.count * value))
        }
    }
    
    func reduce(state: inout State, mutate: Mutation) {
        switch mutate {
        case let .setCount(value):
            print("setCount \(value)")
            state.count = value
            
        case let .setCount1(value):
            print("setCount1 \(value)")
            state.count1 = value
        }
    }
    
    func transformAction() -> AnyPublisher<Action, Never> {
        let customAction = PassthroughSubject<Action, Never>()

//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            customAction.send(.increase)
//        }
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//            customAction.send(.multiply(5))
//        }
        
        return .merge([
            customAction.eraseToAnyPublisher(),
        ])
    }
    
    func fetchUserData() async -> String {
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2초 대기 (네트워크 요청 시뮬레이션)
        return "User Data"
    }

    func fetchOtherData() async -> String {
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2초 대기
        return "Other Data"
    }
}
