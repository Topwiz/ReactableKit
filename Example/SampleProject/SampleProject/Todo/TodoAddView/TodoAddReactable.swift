//
//  TodoAddReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 3/21/25.
//

import Foundation
import ReactableKit

@MainActor
final class TodoAddReactable: Reactable, PathState {
    
    enum Action {
        case titleChanged(String)
        case contentChanged(String)
        case addTodoTapped
    }
    
    enum Mutation {
        case updateAddButtonEnabled
        case addTodo
        case dismiss
    }
    
    struct State {
        @ViewState var title: String = ""
        @ViewState var content: String = ""
        @ViewState var folder: TodoFolder?
        @ViewState var addButtonEnabled: Bool = false
        @Emit var dismiss: Bool = true
    }
    
    let initialState: State = .init()
    
    func mutate(action: Action, state: State, send: @escaping MutationSender<Mutation>) async {
        switch action {
        case .titleChanged,
                .contentChanged:
            await send(.updateAddButtonEnabled)
            
        case .addTodoTapped:
            await send(.addTodo)
            await send(.dismiss)
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case .updateAddButtonEnabled:
            state.addButtonEnabled = !state.title.isEmpty && !state.content.isEmpty
            
        case .addTodo:
            @Shared(.file()) var todoList: [UUID: TodoItem] = [:]
            let item = TodoItem(title: state.title, content: state.content)
            todoList[item.id] = item
            
        case .dismiss:
            state.dismiss = true
        }
    }
}

