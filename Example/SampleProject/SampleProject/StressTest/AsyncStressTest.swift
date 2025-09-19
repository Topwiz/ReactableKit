//
//  AsyncStressTest.swift
//  ReactableExample
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import SwiftUI
import ReactableKit

// MARK: - AsyncStressTestReactable

@MainActor
final class AsyncStressTestReactable: Reactable, PathState {
    
    enum Action: Sendable {
        case increment
        case decrement
        case asyncIncrement(delay: UInt64)
        case batchIncrement(count: Int)
        case stressTest(actionCount: Int)
        case reset
        case concurrentTest
    }
    
    struct State: Sendable {
        @ViewState var counter: Int = 0
        @ViewState var pendingOperations: Int = 0
        @ViewState var totalActions: Int = 0
        @ViewState var lastExecutionTime: Double = 0
        @ViewState var isStressTesting: Bool = false
        @ViewState var concurrentTasks: [String] = []
    }
    
    enum Mutation: Sendable {
        case updateCounter(Int)
        case updatePendingOperations(Int)
        case updateTotalActions(Int)
        case updateExecutionTime(Double)
        case setStressTesting(Bool)
        case addConcurrentTask(String)
        case removeConcurrentTask(String)
    }
    
    let initialState = State()
    
    func mutate(action: Action, state: State, send: MutationSender<Mutation>) async {
        await send(.updateTotalActions(state.totalActions + 1))
        
        switch action {
        case .increment:
            await send(.updateCounter(state.counter + 1))
            
        case .decrement:
            await send(.updateCounter(state.counter - 1))
            
        case let .asyncIncrement(delay):
            let taskId = UUID().uuidString
            await send(.addConcurrentTask("Async +1 (\(delay/1_000_000)ms)"))
            await send(.updatePendingOperations(state.pendingOperations + 1))
            
            // 지연 시뮬레이션
            try? await Task.sleep(nanoseconds: delay)
            
            await send(.updateCounter(state.counter + 1))
            await send(.updatePendingOperations(state.pendingOperations - 1))
            await send(.removeConcurrentTask("Async +1 (\(delay/1_000_000)ms)"))
            
        case let .batchIncrement(count):
            await send(.updatePendingOperations(state.pendingOperations + 1))
            
            for i in 1...count {
                await send(.updateCounter(state.counter + 1))
                if i % 10 == 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000)
                }
            }
            
            await send(.updatePendingOperations(state.pendingOperations - 1))
            
        case let .stressTest(actionCount):
            await send(.setStressTesting(true))
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // 다양한 action을 빠르게 발생
            for i in 0..<actionCount {
                switch i % 4 {
                case 0:
                    await send(.updateCounter(state.counter + 1))
                case 1:
                    await send(.updateCounter(state.counter - 1))
                case 2:
                    await send(.updateCounter(state.counter + 2))
                default:
                    await send(.updateCounter(state.counter - 2))
                }
            }
            
            let executionTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // ms
            await send(.updateExecutionTime(executionTime))
            await send(.setStressTesting(false))
            
        case .reset:
            await send(.updateCounter(0))
            await send(.updatePendingOperations(0))
            await send(.updateTotalActions(0))
            await send(.updateExecutionTime(0))
            await send(.setStressTesting(false))
            
        case .concurrentTest:
            // 여러 비동기 작업을 동시에 실행
            await send(.setStressTesting(true))
            
            // 10개의 동시 작업 시작 (Task 생성 없이 send만 사용)
            for i in 1...10 {
                let delay = UInt64.random(in: 10_000_000...100_000_000) // 10-100ms
                let taskName = "Task \(i) (\(delay/1_000_000)ms)"
                await send(.addConcurrentTask(taskName))
                await send(.updatePendingOperations(state.pendingOperations + 1))
                
                // 각 작업 시뮬레이션
                try? await Task.sleep(nanoseconds: delay)
                
                await send(.updateCounter(state.counter + i))
                await send(.updatePendingOperations(state.pendingOperations - 1))
                await send(.removeConcurrentTask(taskName))
            }
            
            await send(.setStressTesting(false))
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .updateCounter(value):
            state.counter = value
        case let .updatePendingOperations(value):
            state.pendingOperations = value
        case let .updateTotalActions(value):
            state.totalActions = value
        case let .updateExecutionTime(time):
            state.lastExecutionTime = time
        case let .setStressTesting(value):
            state.isStressTesting = value
        case let .addConcurrentTask(name):
            state.concurrentTasks.append(name)
        case let .removeConcurrentTask(name):
            state.concurrentTasks.removeAll { $0 == name }
        }
    }
}

// MARK: - AsyncStressTestView

struct AsyncStressTestView: View {
    @StateObject private var store: Store<AsyncStressTestReactable>
    
    init(reactable: AsyncStressTestReactable) {
        self._store = StateObject(wrappedValue: Store(reactable))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 상태 표시
                VStack(spacing: 10) {
                    HStack {
                        Text("Counter:")
                        Spacer()
                        Text("\(store.state.counter)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text("Pending Operations:")
                        Spacer()
                        Text("\(store.state.pendingOperations)")
                            .foregroundColor(store.state.pendingOperations > 0 ? .orange : .green)
                    }
                    
                    HStack {
                        Text("Total Actions:")
                        Spacer()
                        Text("\(store.state.totalActions)")
                    }
                    
                    if store.state.lastExecutionTime > 0 {
                        HStack {
                            Text("Last Execution Time:")
                            Spacer()
                            Text(String(format: "%.2f ms", store.state.lastExecutionTime))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // 동시 실행 중인 작업 표시
                if !store.state.concurrentTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Running Tasks:")
                            .font(.headline)
                        ForEach(store.state.concurrentTasks, id: \.self) { task in
                            Text("• \(task)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Divider()
                
                // 기본 액션 버튼
                VStack(spacing: 10) {
                    Text("Basic Actions")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        Button("Increment") {
                            Task { await store.action(.increment) }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Decrement") {
                            Task { await store.action(.decrement) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Divider()
                
                // 비동기 테스트
                VStack(spacing: 10) {
                    Text("Async Tests")
                        .font(.headline)
                    
                    HStack(spacing: 10) {
                        Button("Async +1 (10ms)") {
                            Task { await store.action(.asyncIncrement(delay: 10_000_000)) }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Async +1 (100ms)") {
                            Task { await store.action(.asyncIncrement(delay: 100_000_000)) }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Async +1 (500ms)") {
                            Task { await store.action(.asyncIncrement(delay: 500_000_000)) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Divider()
                
                // 스트레스 테스트
                VStack(spacing: 10) {
                    Text("Stress Tests")
                        .font(.headline)
                    
                    Button("Batch +100") {
                        Task { await store.action(.batchIncrement(count: 100)) }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Stress Test (1000 actions)") {
                        Task { await store.action(.stressTest(actionCount: 1000)) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.state.isStressTesting)
                    
                    Button("Concurrent Test (10 tasks)") {
                        Task { await store.action(.concurrentTest) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.state.isStressTesting)
                    
                    // 동시 다발적 액션 발생
                    Button("Fire 50 Concurrent Increments") {
                        // 50개의 increment를 동시에 실행하여 동시성 테스트
                        let expectedCount = store.state.counter + 50
                        for i in 0..<50 {
                            Task {
                                await store.action(.increment)
                            }
                        }
                        // 1초 후 결과 확인
                        Task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            print("Expected: \(expectedCount), Actual: \(store.state.counter)")
                            if store.state.counter != expectedCount {
                                print("⚠️ Race condition detected! \(store.state.counter) != \(expectedCount)")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.red)
                }
                
                Divider()
                
                Button("Reset") {
                    Task { await store.action(.reset) }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                if store.state.isStressTesting {
                    ProgressView("Testing...")
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Async Stress Test")
    }
}

#Preview {
    NavigationView {
        AsyncStressTestView(reactable: AsyncStressTestReactable())
    }
}
