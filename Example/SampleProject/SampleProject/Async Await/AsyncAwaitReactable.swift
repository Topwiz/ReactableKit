//
//  AsyncAwaitReactable.swift
//  ExmapleApp
//
//  Created by JeeHoon Son on 3/21/25.
//

import ReactableKit
import DependencyInjectableKit

final class AsyncAwaitReactable: Reactable, PathState, @unchecked Sendable {
    
    enum Action {
        case run
        case cancel
    }
    
    enum Mutation {
        case setCount(Int)
    }
    
    struct State {
        @ViewState var count: Int = 0
    }
    
    @Dependency(\.service) var service
    let initialState: State = State()
    var cancelTask: PassthroughSubject<Void, Never> = .init()

    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .run:
            return .run { [service] send in
                await send(.setCount(1))
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds delay
                await send(.setCount(2))
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds delay
                guard !Task.isCancelled else { return }
                print(service.test())
                await send(.setCount(3))
            }
            .takeUntil(self.cancelTask.eraseToAnyPublisher())
            
        case .cancel:
            self.cancelTask.send(())
            return .empty()
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .setCount(value):
            state.count = value
        }
    }
}

