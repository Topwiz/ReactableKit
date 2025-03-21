//
//  NavigationStackView.swift
//  ReactableExmaple
//
//  Created by Jeehoon Son on 1/24/25.
//

import SwiftUI
@_exported import ReactableKit

struct NavigationStackView: View {
    @StateObject var store = Store(NavigationStackReactable())
    
    var body: some View {
        NavigationStack(reactablePath: self.$store.state.path) {
            List {
                Section("Use Case Example") {
                    Button {
                        self.store.action(.pushCounter)
                    } label: {
                        Text("Basic Counter Example")
                    }
                    
                    NavigationLink {
                        AsyncAwaitReactable()
                    } label: {
                        Text("Async Await Example")
                    }
                    
                    NavigationLink {
                        BindingReactable()
                    } label: {
                        Text("[NavigationLink] Binding")
                    }
    
                    NavigationLink {
                        SharedStateReactable()
                    } label: {
                        Text("[NavigationLink] SharedStateReactable")
                    }
    
                    NavigationLink {
                        UIKitExampleReactable()
                    } label: {
                        Text("[NavigationLink] UIKitExample")
                    }
    
                    NavigationLink {
                        ForEachReactable()
                    } label: {
                        Text("[NavigationLink] ForEach")
                    }
                }
                
                Section("Project Example") {
                    
                    NavigationLink {
                        TodoListReactable()
                    } label: {
                        Text("Todo")
                    }
                }
            }
        } destination: { reactable in
            switch reactable {
            case let reactable as CounterReactable:
                CounterView(reactable: reactable)
                
            case let reactable as BindingReactable:
                BindingView(store: Store(reactable))
                
            case let reactable as SharedStateReactable:
                SharedStateView(store: Store(reactable))
            
            case let reactable as UIKitExampleReactable:
                SwiftUIUIView()
                
            case let reactable as ForEachReactable:
                ForEachView(store: Store(reactable))
                
            case let reactable as AsyncAwaitReactable:
                AsyncAwaitView(reactable: reactable)
                
            case let reactable as TodoListReactable:
                TodoListView(reactable: reactable)
                
            case let reactable as TodoAddReactable:
                TodoAddView(reactable: reactable)
                
            default:
                EmptyView()
            }
        }
        
    }
}

#Preview {
    NavigationStackView()
}
