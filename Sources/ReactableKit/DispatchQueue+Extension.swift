//
//  DispatchQueue+Extension.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 6/10/25.
//


import Foundation

public extension DispatchQueue {
    
    func asyncRun<T>(
        priority: TaskPriority? = nil,
        operation: @Sendable @escaping () async -> T
    ) async -> T {
        await withCheckedContinuation { continuation in
            self.async {
                Task {
                    let result = await operation()
                    continuation.resume(returning: result)
                }
            }
        }
    }

    func asyncRun<T>(
        priority: TaskPriority? = nil,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            self.async {
                Task {
                    do {
                        let result = try await operation()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
