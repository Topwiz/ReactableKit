//
//  ObservableEvent.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/3/25.
//

import Foundation
import Combine

public protocol ObservableEvent {
    static func observe() -> AnyPublisher<Self, Never>
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
