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

private final class LocalCountingService: Sendable {
    static let instanceCount = Counter()

    init() {
        LocalCountingService.instanceCount.increment()
    }
}

extension LocalCountingService: DependencyInjectable {
    static var real: LocalCountingService { LocalCountingService() }
}

extension GlobalDependencyKey {
    fileprivate var localCountingService: LocalCountingService { self[LocalCountingService.self] }
}

private struct AccessorHolder {
    var serviceViaExplicitGetter: LocalCountingService {
        get {
            @Dependency(\.localCountingService) var service: LocalCountingService
            return service
        }
    }

    /// An implicit getter body inside a type resolves through the property
    /// wrapper, not the macro — the annotation is optional there.
    var serviceViaImplicitGetter: LocalCountingService {
        @Dependency(\.localCountingService) var service
        return service
    }
}

private final class SendableHolder: Sendable {
    @Dependency(\.countingService) var service: CountingService // a trailing comment must not leak into the expansion
}

private actor ActorHolder {
    @Dependency(\.countingService) var service: CountingService

    func read() -> CountingService { self.service }
}

private struct NestedInner: DependencyInjectable, Equatable {
    static var real: NestedInner { NestedInner() }
}

extension GlobalDependencyKey {
    fileprivate var nestedInner: NestedInner { self[NestedInner.self] }
}

private struct NestedOuter: DependencyInjectable {
    let inner: NestedInner

    static var real: NestedOuter {
        @Dependency(\.nestedInner) var inner
        return NestedOuter(inner: inner)
    }
}

extension GlobalDependencyKey {
    fileprivate var nestedOuter: NestedOuter { self[NestedOuter.self] }
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

    @Test
    func resolvesInsideFunctionBody() {
        let before = LocalCountingService.instanceCount.current
        func resolveLocally() -> (LocalCountingService, LocalCountingService) {
            @Dependency(\.localCountingService) var service: LocalCountingService
            #expect(LocalCountingService.instanceCount.current == before, "Declaration alone should not resolve")
            return (service, service)
        }

        let (first, second) = resolveLocally()
        #expect(first === second, "Repeated access should return the same instance")
        #expect(LocalCountingService.instanceCount.current == before + 1, "First access should resolve exactly once")
    }

    @Test
    func resolvesInsideAccessorBody() {
        let holder = AccessorHolder()
        let implicit = holder.serviceViaImplicitGetter
        let explicit = holder.serviceViaExplicitGetter
        #expect(implicit !== explicit, "each declaration owns its resolution, as a member does")
    }

    /// The shared cache must release its own lock before the storage resolves,
    /// or one dependency resolving another deadlocks.
    @Test
    func resolvesADependencyThatResolvesAnother() {
        @Dependency(\.nestedOuter) var outer
        @Dependency(\.nestedInner) var inner
        #expect(outer.inner == inner)
    }

    @Test
    func propertyWrapperMatchesTheMacro() {
        // One declaration caches; a second declaration resolves its own — the
        // same contract a member declaration has across two instances.
        func resolveTwice() -> (LocalCountingService, LocalCountingService) {
            @Dependency(\.localCountingService) var service
            return (service, service)
        }
        let (first, second) = resolveTwice()
        #expect(first === second)
        #expect(resolveTwice().0 !== resolveTwice().0)
        #expect(SendableHolder().service !== SendableHolder().service)
    }
}
