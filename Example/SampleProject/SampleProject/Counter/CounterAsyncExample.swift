//
//  CounterAsyncExample.swift
//  ReactableExample
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import SwiftUI
import ReactableKit
import Combine

// MARK: - AsyncCounterReactable
@MainActor
final class AsyncCounterReactable: Reactable, PathState {
    
    enum Action: Sendable {
        case increase
        case decrease
        case asyncIncrease
    }
    
    struct State: Sendable {
        @ViewState var count: Int = 1
        @ViewState var isLoading: Bool = false
    }
    
    enum Mutation: Sendable {
        case setCount(Int)
        case setLoading(Bool)
    }
    
    let initialState: State
    
    init(state: State = .init()) {
        self.initialState = state
    }
    
    func mutate(action: Action, state: State, send: MutationSender<Mutation>) async {
        switch action {
        case .increase:
            await send(.setCount(state.count + 1))
            
        case .decrease:
            await send(.setCount(state.count - 1))
            
        case .asyncIncrease:
            await send(.setLoading(true))
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await send(.setCount(state.count + 10))
            await send(.setLoading(false))
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .setCount(value):
            state.count = value
        case let .setLoading(value):
            state.isLoading = value
        }
    }
}

// MARK: - AsyncCounterView
struct AsyncCounterView: View {
    @StateObject private var store: Store<AsyncCounterReactable>
    
    init(reactable: AsyncCounterReactable) {
        self._store = StateObject(wrappedValue: Store(reactable))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Async Counter: \(store.state.count)")
                .font(.largeTitle)
            
            if store.state.isLoading {
                ProgressView()
            }
            
            HStack(spacing: 20) {
                Button("-") {
                    Task { await store.action(.decrease) }
                }
                
                Button("+") {
                    Task { await store.action(.increase) }
                }
                
                Button("Async +10") {
                    Task { await store.action(.asyncIncrease) }
                }
            }
        }
        .padding()
    }
}
