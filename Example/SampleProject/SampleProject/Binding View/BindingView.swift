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

            self.store.updateOn(\.isOn1) { value in
                Toggle(isOn: value) {
                    Text("Toggle 1 updateOn")
                }
                .background(Color.random())
            }

            Toggle(
                isOn: self.store.binding(\.isOn1) { value in
                    print("value: \(value)")
                    return .isOnChanged
                }
            ) {
                Text("Toggle 1 normal binding")
            }
            .background(Color.random())
            
            self.store.updateOn(\.isOn1) { value in
                Toggle(isOn: value) {
                    Text("Toggle 1 updateOn with action")
                }
                .background(Color.random())
                
            } action: { newValue in
                .isOnChanged
            }
            
            self.store.updateOn(\.isOn2) { value in
                Toggle(
                    isOn: value
                ) {
                    Text("Toggle 2 updateOn")
                }
                .background(Color.random())
            }
            
            HStack {
                Slider(value: self.store.binding(\.slider))
                
                Text("\(self.store.state.slider)")
            }
            .background(Color.random())
                
            Button {
                self.store.action(.emitTest)
            } label: {
                Text("emitTest")
            }
            .background(Color.random())
        }
        .padding(20)
        .emit(\.$emitTest, from: self.store) { value in
            print("emitTest: \(value)")
        }.onDisappear {
            print("BindingView.onDisappear called!")
        }
    }
}

#Preview {
    BindingView()
}
