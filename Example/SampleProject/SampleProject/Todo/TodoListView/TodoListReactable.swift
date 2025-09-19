//
//  TodoListReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 3/21/25.
//

import Foundation
import ReactableKit

@MainActor
final class TodoListReactable: Reactable, PathState {
    
    enum Action {
        case todoListUpdated(todoList: [UUID: TodoItem])
        case toggleItem(item: TodoItem)
        case removeItem(indexSet: IndexSet)
    }
    
    enum Mutation {
        case bypass(Action)
    }
    
    struct State {
        @Shared(.file()) var todoDataList: [UUID: TodoItem] = [:]
        @ViewState var todoList: [TodoItem] = []
        
        init() {
            self.todoList = self.todoDataList.map { $0.value }
        }
    }
    
    let initialState: State = State()
    
    func mutate(action: Action, state: State, send: @escaping MutationSender<Mutation>) async {
        await send(.bypass(action))
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .bypass(.todoListUpdated(todoList)):
            state.todoList = todoList.map { $0.value }
            
        case let .bypass(.toggleItem(item)):
            let isFinsihed = state.todoDataList[item.id]?.finishedAt != nil
            state.todoDataList[item.id]?.finishedAt = !isFinsihed ? .init() : nil
            
        case let .bypass(.removeItem(indexSet)):
            guard let item = indexSet.map({ state.todoList[$0] }).first else { return }
            state.todoDataList[item.id] = nil
        }
    }
    
    func transformAction() -> AsyncStream<Action>? {
        return AsyncStream { continuation in
            Task {
                for await value in self.state.$todoDataList.publisher.values {
                    continuation.yield(.todoListUpdated(todoList: value))
                }
            }
        }
    }
}
