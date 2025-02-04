//
//  SharedStateView.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/28/25.
//

import SwiftUI

struct SharedStateView: View {
    
    @StateObject var store = Store {
        SharedStateReactable()
    }
    
    var drawable: SharedStateReactable.Drawable { self.store.state.drawable }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Shared State")
                .padding()
                
            SharedStateChildView(store: Store { SharedStateChildReactable() })
            
            Text("Age: \(self.drawable.age)")
            
            Text("isPremium: \(self.drawable.isPremium)")
            
            HStack {
                Button {
                    self.store.action(.changeData)
                } label: {
                    Text("Change Data")
                }
                
                Button {
                    self.store.action(.removeAllData)
                } label: {
                    Text("Remove Data")
                }
            }
        }
    }
}

#Preview {
    SharedStateView()
}
