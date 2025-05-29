//
//  ReplaySubject.swift
//  NaviUtils
//
//  Created by Jeehoon Son on 5/12/25.
//  Copyright © 2025 Reactable. All rights reserved.
//

import Foundation
import Combine

final class ReplaySubject<Output, Failure: Error>: Publisher {
    typealias Output = Output
    typealias Failure = Failure

    private var buffer: [Output] = []
    private let bufferSize: Int
    private var subscribers: [AnySubscriber<Output, Failure>] = []
    private var completion: Subscribers.Completion<Failure>?
    private let passthrough = PassthroughSubject<Output, Failure>()
    private let lock = DispatchQueue(label: "replaysubject.lock")

    init(bufferSize: Int) {
        self.bufferSize = bufferSize
    }

    func send(_ value: Output) {
        self.lock.sync { [weak self] in
            guard let self else { return }
            self.buffer.append(value)
            if self.buffer.count > self.bufferSize {
                self.buffer.removeFirst()
            }
            for subscriber in self.subscribers {
                _ = subscriber.receive(value)
            }
            self.passthrough.send(value)
        }
    }

    func send(completion: Subscribers.Completion<Failure>) {
        self.lock.sync { [weak self] in
            guard let self else { return }
            self.completion = completion
            for subscriber in self.subscribers {
                subscriber.receive(completion: completion)
            }
            self.passthrough.send(completion: completion)
        }
    }

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        self.lock.sync { [weak self] in
            guard let self else { return }
            let anySubscriber = AnySubscriber(subscriber)
            self.subscribers.append(anySubscriber)

            for value in self.buffer {
                _ = anySubscriber.receive(value)
            }

            if let completion = self.completion {
                anySubscriber.receive(completion: completion)
            }

            subscriber.receive(subscription: Subscriptions.empty)
        }
    }

    func publisher() -> AnyPublisher<Output, Failure> {
        self.passthrough.eraseToAnyPublisher()
    }
}
