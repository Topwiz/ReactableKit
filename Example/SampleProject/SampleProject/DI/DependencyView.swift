//
//  DependencyView.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 8/31/26.
//

import SwiftUI
import ReactableKit

struct DependencyView: View {
    @StateObject private var store = Store(DependencyReactable())

    var body: some View {
        List {
            Section("Resolve from anywhere") {
                Button("Resolve on MainActor (Reactable)") {
                    self.store.action(.resolveOnMain)
                }

                Button("Resolve on background (Sendable class)") {
                    self.store.action(.resolveOnBackground)
                }

                Button("Resolve inside an actor") {
                    self.store.action(.resolveInActor)
                }
            }

            Section("Isolated conformance") {
                Button("Resolve a @MainActor-only dependency") {
                    self.store.action(.resolveMainActorOnly)
                }

                Text("SessionStore conforms as `extension SessionStore: @MainActor DependencyInjectable`, so it can only be resolved from the main actor. The compiler enforces it — there is no separate protocol.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Log") {
                if self.store.state.logs.isEmpty {
                    Text("Tap a button above.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(self.store.state.logs.enumerated()), id: \.offset) { _, log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                    }

                    Button("Clear", role: .destructive) {
                        self.store.action(.clear)
                    }
                }
            }
        }
        .navigationTitle("Dependency Injection")
    }
}

#Preview {
    NavigationStack {
        DependencyView()
    }
}
