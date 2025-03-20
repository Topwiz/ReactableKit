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
                Button {
                    self.store.action(.pushCounter)
                } label: {
                    Text("Basic Counter")
                }
                
                NavigationLink(reactable: self.store.state.counterReactable) {
                    Text("Stored Counter")
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
                
            default:
                EmptyView()
            }
        }
        
    }
}

#Preview {
    NavigationStackView()
}
