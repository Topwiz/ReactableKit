//
//  DependencyInjectableTests.swift
//  ReactableKit
//

import Foundation
import Testing
@testable import DependencyInjectableKit

private final class CountingService: Sendable {
    static let instanceCount = Counter()

    init() {
        CountingService.instanceCount.increment()
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.value += 1
    }

    var current: Int {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.value
    }
}

extension CountingService: DependencyInjectable {
    static var real: CountingService { CountingService() }
}

extension GlobalDependencyKey {
    fileprivate var countingService: CountingService { self[CountingService.self] }
}

private final class SendableHolder: Sendable {
    @Dependency(\.countingService) var service: CountingService // a trailing comment must not leak into the expansion
}

private actor ActorHolder {
    @Dependency(\.countingService) var service: CountingService

    func read() -> CountingService { self.service }
}

struct DependencyInjectableTests {

    @Test
    func resolvesLazilyOnFirstAccess() {
        let before = CountingService.instanceCount.current
        let holder = SendableHolder()
        #expect(CountingService.instanceCount.current == before, "Resolution should be deferred until first access")

        _ = holder.service
        #expect(CountingService.instanceCount.current == before + 1, "First access should resolve exactly once")
    }

    @Test
    func cachesResolvedValue() {
        let holder = SendableHolder()
        let first = holder.service
        let second = holder.service
        #expect(first === second, "Repeated access should return the same instance")
    }

    @Test
    func concurrentFirstAccessResolvesOnce() async {
        let holder = SendableHolder()
        let before = CountingService.instanceCount.current

        let results = await withTaskGroup(of: ObjectIdentifier.self) { group in
            for _ in 0..<64 {
                group.addTask { ObjectIdentifier(holder.service) }
            }
            var collected: Set<ObjectIdentifier> = []
            for await id in group {
                collected.insert(id)
            }
            return collected
        }

        #expect(results.count == 1, "Concurrent first access should yield a single instance")
        #expect(CountingService.instanceCount.current == before + 1, "Resolution should happen exactly once")
    }

    @Test
    func resolvesInsideActor() async {
        let holder = ActorHolder()
        let service = await holder.read()
        #expect(service === (await holder.read()))
    }
}
