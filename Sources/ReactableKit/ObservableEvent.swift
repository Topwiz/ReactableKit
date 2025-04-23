//
//  ObservableEvent.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/3/25.
//

import Foundation
import Combine

public protocol ObservableEvent where Self: Reactable {
    /// Returns a publisher that emits values whenever an event of this type is sent.
    /// - Returns: An `AnyPublisher` emitting instances of the event.
    static func observe() -> AnyPublisher<ObservableEventResult<Self>, Never>
    
    /// Sends an event to all subscribers.
    /// - Parameter action: The event instance to send.
    func send(_ action: Action, state: State)
}

public extension ObservableEvent {
    
    static func observe() -> AnyPublisher<ObservableEventResult<Self>, Never> {
        let key = String(describing: Self.self)
        return Cache.observableEvent.forceCastedValue(forKey: key, default: PassthroughSubject<ObservableEventResult<Self>, Never>())
            .eraseToAnyPublisher()
    }
    
    func send(_ action: Action, state: State) {
        let key = String(describing: Self.self)
        if let subject = Cache.observableEvent.value(forKey: key) as? PassthroughSubject<ObservableEventResult<Self>, Never> {
            let result = ObservableEventResult<Self>(action: action, state: state)
            subject.send(result)
        }
    }
}

public struct ObservableEventResult<R: Reactable>: @unchecked Sendable {
    public let action: R.Action
    public var state: R.State
}

private struct AnyObservableEvent {
    private let _send: (Any, Any) -> Void

    public init<E: ObservableEvent>(_ event: E) {
        self._send = { action, state in
            if let action = action as? E.Action, let state = state as? E.State {
                event.send(action, state: state)
            }
        }
    }

    public func send(action: Any, state: Any) {
        _send(action, state)
    }
}

extension Reactable {
    func sendGlobalActionIfNeeded(_ action: Action, state: State) {
        guard let event = self as? any ObservableEvent else { return }
        let anyObservableEvent = AnyObservableEvent(event)
        anyObservableEvent.send(action: action, state: state)
    }
}
