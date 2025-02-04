//
//  SharedStateChildView.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/29/25.
//

import Foundation
import SwiftUI

struct SharedStateChildView: View {
    
    @StateObject var store = Store(SharedStateChildReactable())
    
    var body: some View {
        HStack {
            Text("UserName: \(self.store.state.name)")
            
            Button {
                self.store.action(.change)
                self.store.action(.parentAction(self.store.state.index))
            } label: {
                Text("Change")
            }
        }
    }
}

#Preview {
    SharedStateView()
}
