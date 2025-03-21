//
//  TodoAddView.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 3/21/25.
//

import Foundation
import SwiftUI

public struct TodoAddView: View {
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: Store<TodoAddReactable>
    
    init(reactable: TodoAddReactable) {
        self.store = Store(reactable)
    }
    
    public var body: some View {
        ScrollView(.vertical) {
            VStack {
                
                TextField(
                    "Enter title",
                    text: self.store.binding(\.title) { .titleChanged($0.new) }
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                
                TextEditor(
                    text: self.store.binding(\.content) { .contentChanged($0.new) }
                )
                    .frame(height: 300)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2))
                    )
                    .padding(.horizontal)
            }
            .padding(.vertical, 20)
            
            Button {
                self.store.action(.addTodoTapped)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.8))
                        .frame(height: 50)
                    
                    Text("Add Todo")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding()
                }
            }
            .fixedSize()
            .disabled(!self.store.state.addButtonEnabled)
            .opacity(self.store.state.addButtonEnabled ? 1 : 0.5)
            
        }
        .navigationTitle("Add Todo")
        .emit(\.$dismiss, from: self.store) { _ in
            withAnimation {
                self.dismiss()
            }
        }
    }
}

#Preview {
    NavigationView {
        TodoAddView(reactable: .init())
    }
}
