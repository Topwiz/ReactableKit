//
//  TodoListReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 3/21/25.
//

import Foundation
import ReactableKit

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
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        return .just(.bypass(action))
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
    
    func transformAction() -> AnyPublisher<Action, Never> {
        let todoDataList = self.currentState.$todoDataList.publisher
            .map(Action.todoListUpdated(todoList:))
            .eraseToAnyPublisher()
        
        return .merge([
            todoDataList,
        ])
    }
}
