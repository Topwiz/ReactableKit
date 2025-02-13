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
    @ObservedObject var store = Store(CounterReactable())
    
    var body: some View {
        VStack(spacing: 20) {
            self.store.updateOn(\.count) { value in
                Text("\(value)")
                    .font(.headline)
                    .background(Color.random())
            }
            
            
            self.store.updateOn(\.count1) { value in
                Text("\(value)")
                    .font(.headline)
                    .background(Color.random())
            }
            
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

extension Color {
    static func random() -> Color {
        return Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
}
