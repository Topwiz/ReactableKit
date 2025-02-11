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
                    Text("New Counter")
                }
                
                NavigationLink(reactable: self.store.state.counterReactable) {
                    Text("Stored Counter")
                }
                
                NavigationLink(reactable: BindingReactable()) {
                    Text("[NavigationLink] Binding")
                }
                
                NavigationLink(reactable: SharedStateReactable()) {
                    Text("[NavigationLink] SharedStateReactable")
                }
                
                NavigationLink(reactable: UIKitExampleReactable()) {
                    Text("[NavigationLink] UIKitExample")
                }
            }
        } destination: { state in
            switch state {
            case let reactable as CounterReactable:
                CounterView(store: Store(reactable))
                
            case let reactable as BindingReactable:
                BindingView(store: Store(reactable))
                
            case let reactable as SharedStateReactable:
                SharedStateView(store: Store(reactable))
            
            case let reactable as UIKitExampleReactable:
                SwiftUIUIView()
                
            default:
                EmptyView()
            }
        }
        
    }
}

#Preview {
    NavigationStackView()
}
