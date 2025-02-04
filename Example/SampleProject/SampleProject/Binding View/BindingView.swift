//
//  BindingView.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 1/26/25.
//

import SwiftUI

struct BindingView: View {
    @ObservedObject var store = Store {
        BindingReactable()
    }
    
    var body: some View {
        VStack {
            Toggle(
                isOn: self.store.binding(
                    self.$store.state.isOn1,
                    action: { _ in
                        .isOnChanged
                    }
                )
            ) {
                Text("Toggle 1")
            }
            
            Toggle(
                isOn: self.$store.state.isOn2
            ) {
                Text("Toggle 2")
            }
            
            HStack {
                Slider(value: self.$store.state.slider)
                
                Text("\(self.store.state.slider)")
            }
                
        }
        .padding(20)
    }
}

#Preview {
    BindingView()
}
