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
                
                NavigationLink(state: self.store.state.storedCounter) {
                    Text("Stored Counter")
                }
                
                NavigationLink(state: BindingReactable.State()) {
                    Text("[NavigationLink] Binding")
                }
                
                NavigationLink(state: SharedStateReactable.State()) {
                    Text("[NavigationLink] SharedStateReactable")
                }
                
                NavigationLink(state: UIKitExampleReactable.State()) {
                    Text("[NavigationLink] UIKitExample")
                }
            }
        } destination: { state in
            switch state {
            case let state as CounterReactable.State:
                CounterView(store: Store(.init(state: state)))
                
            case let state as BindingReactable.State:
                BindingView(store: Store(.init(state: state)))
                
            case let state as SharedStateReactable.State:
                SharedStateView(store: Store(.init(state: state)))
            
            case let state as UIKitExampleReactable.State:
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
