//
//  TodoListView.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 3/21/25.
//

import Foundation
import SwiftUI

struct TodoListView: View {

    @StateObject var store: Store<TodoListReactable>
    
    init(reactable: TodoListReactable) {
        self._store = StateObject(wrappedValue: Store(reactable))
    }

    var body: some View {
        List {
            ForEach(self.store.state.todoList) { todo in
                self.itemView(todo)
            }
            .onDelete { indexSet in
                self.store.action(.removeItem(indexSet: indexSet))
            }
        }
        .navigationTitle("Todo List")
        .navigationBarItems(trailing: self.addTodoButton())
    }
    
    private func itemView(_ todo: TodoItem) -> some View {
        HStack {
            Button {
                self.store.action(.toggleItem(item: todo))
            } label: {
                Image(systemName: todo.finishedAt != nil ? "checkmark.circle.fill" : "circle")
                    .renderingMode(.template)
                    
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(todo.title)
                .foregroundColor(todo.finishedAt != nil ? .gray.opacity(0.8) : .primary)
            
            Spacer()
        }
    }
    
    private func addTodoButton() -> some View {
        NavigationLink {
            TodoAddReactable()
        } label: {
            Image(systemName: "plus")
        }
    }
}

#Preview {
    @Shared var todoList: [UUID: TodoItem] = [
        .init(): .init(title: "111", content: "222", finishedAt: .init()),
        .init(): .init(title: "222", content: "333"),
    ]
    
    NavigationView {
        TodoListView(reactable: .init())
    }
    
}
