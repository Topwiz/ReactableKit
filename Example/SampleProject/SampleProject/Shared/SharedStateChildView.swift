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
                Task {
                    let t = await self.store.action(.change)
                    print("task result: \(t)")
                }
            } label: {
                Text("Change")
            }
        }
    }
}

#Preview {
    SharedStateView()
}
