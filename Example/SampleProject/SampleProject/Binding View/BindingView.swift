//
//  BindingView.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/26/25.
//

import SwiftUI

struct BindingView: View {
    @ObservedObject var store = Store(BindingReactable())
    
    var body: some View {
        VStack {
            Toggle(
                isOn: self.store.binding(\.isOn1) { value in
                    print("value: \(value)")
                    return .isOnChanged
                }
            ) {
                Text("Toggle 1")
            }
            
            Toggle(
                isOn: self.$store.state.isOn2
            ) {
                Text("Toggle 2")
            }
            
            HStack {
                Slider(value: self.store.binding(\.slider))
                
                Text("\(self.store.state.slider)")
            }
            
                
            Button {
                self.store.action(.emitTest)
            } label: {
                Text("emitTest")
            }
        }
        .padding(20)
        .emit(\.$emitTest, from: self.store) { value in
            print("emitTest: \(value)")
        }
    }
}

#Preview {
    BindingView()
}
