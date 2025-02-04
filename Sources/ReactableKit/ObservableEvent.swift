//
//  ObservableEvent.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/3/25.
//

import Foundation
import Combine

public protocol ObservableEvent {
    /// Returns a publisher that emits values whenever an event of this type is sent.
    /// - Returns: An `AnyPublisher` emitting instances of the event.
    static func observe() -> AnyPublisher<Self, Never>
    
    /// Sends an event to all subscribers.
    /// - Parameter action: The event instance to send.
    static func send(_ action: Self)
}

public extension ObservableEvent {
    static func observe() -> AnyPublisher<Self, Never> {
        let key = String(describing: Self.self)
        return Cache.observableEvent.forceCastedValue(forKey: key, default: PassthroughSubject<Self, Never>())
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    static func send(_ event: Self) {
        let key = String(describing: Self.self)
        if let subject = Cache.observableEvent.value(forKey: key) as? PassthroughSubject<Self, Never> {
            subject.send(event)
        }
    }
}
