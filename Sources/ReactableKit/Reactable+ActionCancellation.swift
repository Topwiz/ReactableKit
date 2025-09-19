//
//  AsyncReactable+ActionCancellation.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation

/// Action cancellation manager
@MainActor
final class ActionCancellationManager<Action: Hashable & Sendable> {
    private var runningTasks: [Action: Set<Task<Void, Never>>] = [:]
    
    /// Register a task for an action
    func register(_ task: Task<Void, Never>, for action: Action) {
        if self.runningTasks[action] == nil {
            self.runningTasks[action] = []
        }
        self.runningTasks[action]?.insert(task)
        
        let cleanupTask = task
        Task { @MainActor [weak self] in
            await cleanupTask.value
            self?.unregister(cleanupTask, for: action)
        }
    }
    
    /// Unregister a task
    private func unregister(_ task: Task<Void, Never>?, for action: Action) {
        guard let task = task else { return }
        
        self.runningTasks[action]?.remove(task)
        if self.runningTasks[action]?.isEmpty == true {
            self.runningTasks[action] = nil
        }
    }
    
    /// Cancel all tasks for a specific action
    func cancel(_ action: Action) -> Int {
        let tasks = self.runningTasks[action] ?? []
        tasks.forEach { $0.cancel() }
        self.runningTasks[action] = nil
        return tasks.count
    }
    
    /// Cancel all running tasks
    func cancelAll() -> Int {
        var count = 0
        for (_, tasks) in self.runningTasks {
            tasks.forEach { $0.cancel() }
            count += tasks.count
        }
        self.runningTasks.removeAll()
        return count
    }
    
    /// Get count of running tasks for an action
    func runningCount(for action: Action) -> Int {
        self.runningTasks[action]?.count ?? 0
    }
    
    /// Get all running actions
    var runningActions: [Action] {
        Array(self.runningTasks.keys)
    }
}

private enum CancellationManagerCache {
    nonisolated(unsafe) static let managers = WeakKeyDictionary<AnyObject, Any>()
}

@MainActor
public extension Reactable where Action: Hashable {
    
    private var cancellationManager: ActionCancellationManager<Action> {
        CancellationManagerCache.managers.forceCastedValue(
            forKey: self,
            default: ActionCancellationManager<Action>()
        )
    }
    
    /// Cancel all running tasks for a specific action
    /// - Parameter action: The action whose tasks should be cancelled
    /// - Returns: Number of cancelled tasks
    @discardableResult
    func cancel(_ action: Action) -> Int {
        self.cancellationManager.cancel(action)
    }
    
    /// Cancel all running tasks
    /// - Returns: Number of cancelled tasks
    @discardableResult
    func cancelAll() -> Int {
        self.cancellationManager.cancelAll()
    }
    
    /// Check if an action has running tasks
    func isRunning(_ action: Action) -> Bool {
        self.cancellationManager.runningCount(for: action) > 0
    }
    
    /// Get all currently running actions
    var runningActions: [Action] {
        self.cancellationManager.runningActions
    }
    
    /// Execute a cancellable block for an action with mutation support
    /// The block will be automatically cancelled if cancel(action) is called
    /// - Parameters:
    ///   - action: The action to associate with this operation
    ///   - state: Current state snapshot
    ///   - send: Mutation sender for sending mutations
    ///   - operation: The async operation to execute. Receives isCancelled check and send functions.
    func withCancellation(
        for action: Action,
        send: @escaping MutationSender<Mutation>,
        operation: @escaping @MainActor @Sendable (
            _ isCancelled: @escaping @Sendable () -> Bool,
            _ send: @escaping MutationSender<Mutation>
        ) async -> Void
    ) async {
        let task = Task { @MainActor in
            let checkCancellation: @Sendable () -> Bool = { Task.isCancelled }
            await operation(checkCancellation, send)
        }
        
        self.cancellationManager.register(task, for: action)
        
        await task.value
    }
}
