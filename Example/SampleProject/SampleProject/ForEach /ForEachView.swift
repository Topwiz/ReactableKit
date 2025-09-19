//
//  ForEachView.swift
//  ExmapleApp
//
//  Created by david-rx-nt-2025-01 on 2/13/25.
//

import SwiftUI

struct ForEachView: View {
    @StateObject var store: Store<ForEachReactable>
    
    var body: some View {
        
        
        HStack {
            
            VStack(spacing: 20) {
                Button {
                    self.store.action(.changeLeft)
                } label: {
                    Text("Left List")
                }
                
                ForEach(self.store.state.leftList) { value in
                    Text("\(value.index)")
                            .font(.headline)
                            .background(Color.random())
                }
            }
            
            Spacer()
            
            VStack(spacing: 20) {
                Button {
                    self.store.action(.changeRight)
                } label: {
                    Text("Right List - updateOn")
                }
                
                ForEach(self.store.state.rightList) { test in
                    HStack {
                        self.store.updateOn(\.rightList, for: test.id, property: \.index) { value in
                            Text("\(value)")
                                .font(.headline)
                                .background(Color.random())
                        }
                        self.store.updateOn(\.rightList, for: test.id, property: \.toggle) { value in
                            Toggle(isOn: value) {
                                Text("Toggle 2 updateOn")
                            }
                            .background(Color.random())
                        }
                    }
                }
            }
            .fixedSize()
        }
        .padding(30)
    }
}

#Preview {
    ForEachView(store: .init(.init()))
}

extension Color {
    static func random() -> Color {
        Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}
