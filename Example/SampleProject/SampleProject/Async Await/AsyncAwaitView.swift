//
//  AsyncAwaitView.swift
//  ExmapleApp
//
//  Created by JeeHoon Son on 3/21/25.
//

import Foundation
import SwiftUI

struct AsyncAwaitView: View {
    
    @StateObject var store: Store<AsyncAwaitReactable>
    
    init(reactable: AsyncAwaitReactable) {
        self._store = StateObject(wrappedValue: Store(reactable))
    }
    
    var body: some View {
        VStack(spacing: CGFloat(self.store.state.count * 10)) {
            Text("Value: \(self.store.state.count)")
                
            Button {
                self.store.action(.run)
            } label: {
                Text("Run")
            }

            Button {
                self.store.action(.cancel)
            } label: {
                Text("Cancel")
            }

        }
    }
}

#Preview {
    AsyncAwaitView(reactable: .init())
}
