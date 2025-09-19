//
//  ObservableEvent.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation

private enum GlobalAsyncEventCache {
    nonisolated(unsafe) static let globalChannel = StrongKeyDictionary<String, Any>()
    nonisolated(unsafe) static let instanceChannel = WeakKeyDictionary<AnyObject, Any>()
}

// MARK: - ObservableEvent Support for AsyncReactable

public protocol ObservableEvent where Self: Reactable {
    /// Returns a stream for all of the same type of `AsyncReactable`.
    static func observe() -> AsyncStream<ObservableEventResult<Self>>
    
    /// Returns a stream for current `AsyncReactable`.
    func observe() -> AsyncStream<ObservableEventResult<Self>>
    
    func send(_ action: Action, state: State)
}

public extension ObservableEvent {
    
    func send(_ action: Action, state: State) {
        let result = ObservableEventResult<Self>(action: action, state: state)
        let key = String(describing: Self.self)
        
        // Send to global channel
        if let globalChannel = GlobalAsyncEventCache.globalChannel.value(forKey: key) as? AsyncChannel<ObservableEventResult<Self>> {
            Task {
                await globalChannel.send(result)
            }
        }
        
        // Send to instance channel
        if let instanceChannel = GlobalAsyncEventCache.instanceChannel.value(forKey: self) as? AsyncChannel<ObservableEventResult<Self>> {
            Task {
                await instanceChannel.send(result)
            }
        }
    }
    
    static func observe() -> AsyncStream<ObservableEventResult<Self>> {
        let key = String(describing: Self.self)
        let channel: AsyncChannel<ObservableEventResult<Self>> = GlobalAsyncEventCache.globalChannel.forceCastedValue(
            forKey: key,
            default: AsyncChannel<ObservableEventResult<Self>>()
        )
        
        return AsyncStream { continuation in
            let task = Task {
                for await event in channel {
                    guard !Task.isCancelled else { break }
                    continuation.yield(event)
                }
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    func observe() -> AsyncStream<ObservableEventResult<Self>> {
        let channel: AsyncChannel<ObservableEventResult<Self>> = GlobalAsyncEventCache.instanceChannel.forceCastedValue(
            forKey: self,
            default: AsyncChannel<ObservableEventResult<Self>>()
        )
        
        return AsyncStream { continuation in
            let task = Task {
                for await event in channel {
                    guard !Task.isCancelled else { break }
                    continuation.yield(event)
                }
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

public struct ObservableEventResult<R: Reactable>: Sendable {
    public let action: R.Action
    public let state: R.State
}

@MainActor
private struct AnyObservableEvent {
    private let _send: @MainActor (Any, Any) -> Void

    public init<E: ObservableEvent>(_ event: E) {
        self._send = { action, state in
            if let action = action as? E.Action, let state = state as? E.State {
                event.send(action, state: state)
            }
        }
    }

    public func send(action: Any, state: Any) {
        self._send(action, state)
    }
}

extension Reactable {
    func sendObservableEvent(_ action: Action, state: State) {
        guard let event = self as? any ObservableEvent else { return }
        let anyObservableEvent = AnyObservableEvent(event)
        anyObservableEvent.send(action: action, state: state)
    }
}
