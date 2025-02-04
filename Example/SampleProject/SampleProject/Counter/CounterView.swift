//
//  CounterView.swift
//  ReactableExmaple
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import SwiftUI
import ReactableKit

struct CounterView: View {
    @ObservedObject var store = Store {
        CounterReactable()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("\(self.store.state.count)")
                .font(.headline)
            
            HStack(spacing: 20) {
                Button {
                    self.store.action(.increase)
                } label: {
                    Text("+")
                }
                
                Button {
                    self.store.action(.decrease)
                } label: {
                    Text("-")
                }
            }
        }
    }
}

#Preview {
    CounterView()
}
