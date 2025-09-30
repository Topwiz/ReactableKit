//
//  SafeAsyncReactable.swift
//  ExmapleApp
//
//  Created by ReactableKit on 3/21/25.
//

import ReactableKit
import Foundation

final class SafeAsyncReactable: Reactable, PathState, @unchecked Sendable {
    
    enum Action {
        case loadUserData
        case loadUserDataWithError
        case cancel
        // Send order test actions
        case testSequentialSends
        case testFastSends
        case testAsyncSends
        case testMixedSends
        case resetLogs
        // External repeated action test
        case externalActionTest(Int) // Receives action number
        case startExternalActionTest
    }
    
    enum Mutation {
        case setLoading(Bool)
        case setUserData(String)
        case setError(String?)
        // Send order test mutations
        case addLog(String)
        case clearLogs
    }
    
    struct State {
        @ViewState var isLoading: Bool = false
        @ViewState var userData: String = ""
        @ViewState var errorMessage: String? = nil
        // Send order test states
        @ViewState var logs: [String] = []
    }
    
    let initialState: State = State()
    var cancelTask: PassthroughSubject<Void, Never> = .init()

    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .loadUserData:
            return .run(priority: .userInitiated) { send in
                // Start loading
                send(.setLoading(true))
                send(.setError(nil))
                
                // Simulate network delay
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                
                // Simulate successful data fetch
                let userData = "User: John Doe, Age: 30"
                send(.setUserData(userData))
                send(.setLoading(false))
            } catch: { error, send in
                // Handle any errors that occur during the async operation
                send(.setLoading(false))
                send(.setError("Failed to load user data: \(error.localizedDescription)"))
            }
            .takeUntil(self.cancelTask.eraseToAnyPublisher())
            
        case .loadUserDataWithError:
            return .run(priority: .userInitiated) { send in
                // Start loading
                send(.setLoading(true))
                send(.setError(nil))
                
                // Simulate network delay
                try await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                
                // Simulate network error
                throw NetworkError.serverError
            } catch: { error, send in
                // This catch block will handle the thrown error
                send(.setLoading(false))
                if let networkError = error as? NetworkError {
                    send(.setError("Network Error: \(networkError.localizedDescription)"))
                } else {
                    send(.setError("Unknown error occurred"))
                }
            }
            .takeUntil(self.cancelTask.eraseToAnyPublisher())
            
        case .cancel:
            self.cancelTask.send(())
            return .just(.setLoading(false))
            
        // MARK: - Send Order Test Cases
        case .testSequentialSends:
            return .run { send in
                send(.setLoading(true))
                send(.addLog("🚀 Sequential test started"))
                
                // 5 consecutive send calls
                for i in 1...5 {
                    send(.addLog("📝 Sequential log \(i)"))
                }
                
                send(.addLog("✅ Sequential test completed"))
                send(.setLoading(false))
            }
            
        case .testFastSends:
            return .run { send in
                send(.setLoading(true))
                send(.addLog("⚡ Fast consecutive test started"))
                
                // 20 fast consecutive send calls
                for i in 1...20 {
                    send(.addLog("⚡ Fast log \(i)"))
                }
                
                send(.addLog("✅ Fast consecutive test completed"))
                send(.setLoading(false))
            }
            
        case .testAsyncSends:
            return .run { send in
                send(.setLoading(true))
                send(.addLog("⏰ Async test started"))
                
                // Send calls in the middle of async operations
                send(.addLog("📍 First checkpoint"))
                
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                send(.addLog("📍 After 0.1 seconds"))
                
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                send(.addLog("📍 After 0.2 seconds"))
                
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                send(.addLog("📍 After 0.3 seconds"))
                
                send(.addLog("✅ Async test completed"))
                send(.setLoading(false))
            }
            
        case .testMixedSends:
            return .run { send in
                send(.setLoading(true))
                send(.addLog("🔄 Mixed test started"))
                
                // Consecutive sends
                for i in 1...3 {
                    send(.addLog("🔢 Consecutive \(i)"))
                }
                
                // Async wait
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                send(.addLog("⏱️ After 0.05 seconds wait"))
                
                // More consecutive sends
                for i in 4...6 {
                    send(.addLog("🔢 Consecutive \(i)"))
                }
                
                // Another async wait
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                send(.addLog("⏱️ After 0.1 seconds wait"))
                
                // Final consecutive sends
                for i in 7...9 {
                    send(.addLog("🔢 Consecutive \(i)"))
                }
                
                send(.addLog("✅ Mixed test completed"))
                send(.setLoading(false))
            }
            
        case .resetLogs:
            return .just(.clearLogs)
            
        case let .externalActionTest(actionNumber):
            return .run { send in
                // Log the action number received by each action
                send(.addLog("🎯 External action #\(actionNumber) started"))
                
                // Simulate short async operation
                try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                
                send(.addLog("🎯 External action #\(actionNumber) completed"))
            }
            
        case .startExternalActionTest:
            return .run { send in
                send(.setLoading(true))
                send(.addLog("🔥 External repeated action test started"))
                
                // Release loading state after test completion
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds wait
                send(.addLog("🔥 External repeated action test ready"))
                send(.setLoading(false))
            }
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .setLoading(isLoading):
            state.isLoading = isLoading
            
        case let .setUserData(userData):
            state.userData = userData
            
        case let .setError(errorMessage):
            state.errorMessage = errorMessage
            
        case let .addLog(log):
            let timestamp = DateFormatter.timeFormatter.string(from: Date())
            state.logs.append("[\(timestamp)] \(log)")
            
        case .clearLogs:
            state.logs = []
        }
    }
}

// MARK: - Network Error

enum NetworkError: Error, LocalizedError {
    case serverError
    case connectionTimeout
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .serverError:
            return "Server returned an error"
        case .connectionTimeout:
            return "Connection timed out"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
