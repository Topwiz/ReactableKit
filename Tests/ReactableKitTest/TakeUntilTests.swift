//
//  TakeUntilTests.swift
//  ReactableKit
//

import Testing
import Combine
@testable import ReactableKit

struct TakeUntilTests {
    private final class SubscriptionCounter {
        var active = 0
    }

    private final class Payload {}

    private func counted(
        _ subject: PassthroughSubject<Void, Never>,
        by counter: SubscriptionCounter
    ) -> AnyPublisher<Void, Never> {
        subject
            .handleEvents(
                receiveSubscription: { _ in counter.active += 1 },
                receiveCompletion: { _ in counter.active -= 1 },
                receiveCancel: { counter.active -= 1 }
            )
            .eraseToAnyPublisher()
    }

    @Test
    func forwardsValuesUntilTriggerFires() {
        let upstream = PassthroughSubject<Int, Never>()
        let trigger = PassthroughSubject<Void, Never>()
        var received: [Int] = []
        var finished = false

        let cancellable = upstream
            .takeUntil(trigger.eraseToAnyPublisher())
            .sink(receiveCompletion: { _ in finished = true }, receiveValue: { received.append($0) })

        upstream.send(1)
        upstream.send(2)
        trigger.send(())
        upstream.send(3)

        #expect(received == [1, 2])
        #expect(finished)
        cancellable.cancel()
    }

    @Test
    func releasesTriggerSubscriptionWhenTriggerFiresFirst() {
        let upstream = PassthroughSubject<Int, Never>()
        let trigger = PassthroughSubject<Void, Never>()
        let counter = SubscriptionCounter()

        let cancellable = upstream
            .takeUntil(self.counted(trigger, by: counter))
            .sink { _ in }

        #expect(counter.active == 1)
        trigger.send(())
        #expect(counter.active == 0)
        cancellable.cancel()
    }

    @Test
    func releasesDownstreamWhenTriggerFiresFirst() {
        let upstream = PassthroughSubject<Int, Never>()
        let trigger = PassthroughSubject<Void, Never>()
        weak var weakPayload: Payload?
        var cancellable: AnyCancellable?

        do {
            let payload = Payload()
            weakPayload = payload
            cancellable = upstream
                .takeUntil(trigger.eraseToAnyPublisher())
                .map { value -> Int in
                    _ = payload
                    return value
                }
                .sink { _ in }
        }

        trigger.send(())
        cancellable?.cancel()
        cancellable = nil

        #expect(weakPayload == nil)
    }

    @Test
    func releasesTriggerSubscriptionWhenUpstreamFinishesFirst() {
        let upstream = PassthroughSubject<Int, Never>()
        let trigger = PassthroughSubject<Void, Never>()
        let counter = SubscriptionCounter()

        let cancellable = upstream
            .takeUntil(self.counted(trigger, by: counter))
            .sink { _ in }

        upstream.send(completion: .finished)
        #expect(counter.active == 0)
        cancellable.cancel()
    }

    @Test
    func releasesTriggerSubscriptionWhenCancelled() {
        let upstream = PassthroughSubject<Int, Never>()
        let trigger = PassthroughSubject<Void, Never>()
        let counter = SubscriptionCounter()

        let cancellable = upstream
            .takeUntil(self.counted(trigger, by: counter))
            .sink { _ in }

        cancellable.cancel()
        #expect(counter.active == 0)
    }

    @Test
    func doesNotRetainTriggerSubscriptionsAcrossRestartedWork() {
        let cancelTasks = PassthroughSubject<Void, Never>()
        let counter = SubscriptionCounter()
        var cancellables = Set<AnyCancellable>()

        for _ in 0..<3 {
            cancelTasks.send(())
            PassthroughSubject<Int, Never>()
                .takeUntil(self.counted(cancelTasks, by: counter))
                .sink { _ in }
                .store(in: &cancellables)
        }
        cancelTasks.send(())

        #expect(counter.active == 0)
    }
}
