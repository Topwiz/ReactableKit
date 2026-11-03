//
//  DependencyOverrides.swift
//  ReactableKit
//

import Foundation

/// Values that replace a dependency's `real`, `preview`, or `test` value inside a
/// `withDependencies(_:operation:)` scope.
///
/// Overrides are keyed by the `DependencyInjectable` type, so every resolution of
/// that type sees them — `@Dependency`, `@LazyDependency`, `@ViewDependency`, and
/// direct `GlobalDependencyKey()` access alike.
///
/// The storage is a task-local value, so overrides follow the current task and its
/// child tasks. Concurrently running tests each see only their own overrides.
public struct DependencyOverrides: Sendable {
    @TaskLocal static var current = DependencyOverrides()

    /// `DependencyType` is not required to be `Sendable`, matching `Dependency`,
    /// which is `@unchecked Sendable` for the same reason.
    private struct Box: @unchecked Sendable {
        let value: Any
    }

    private var storage: [ObjectIdentifier: Box] = [:]

    init() {}

    public subscript<T: DependencyInjectable>(_: T.Type) -> T.DependencyType? {
        get { self.storage[ObjectIdentifier(T.self)]?.value as? T.DependencyType }
        set { self.storage[ObjectIdentifier(T.self)] = newValue.map { Box(value: $0) } }
    }

    public subscript<T: MainActorDependencyInjectable>(_: T.Type) -> T.DependencyType? {
        get { self.storage[ObjectIdentifier(T.self)]?.value as? T.DependencyType }
        set { self.storage[ObjectIdentifier(T.self)] = newValue.map { Box(value: $0) } }
    }
}

/// Runs `operation` with the dependencies that `update` overrides.
///
/// ```swift
/// withDependencies {
///     $0[Service.self] = Service.Mock()
/// } operation: {
///     let sut = Repository()   // @Dependency(\.service) resolves to the mock
/// }
/// ```
///
/// A nested scope starts from the enclosing scope's overrides.
///
/// Overrides reach only code that resolves while `operation` runs on the current
/// task or a child task. A `@Dependency` resolved inside the scope keeps its value
/// afterwards, but a resolution deferred to an escaping closure, a Combine
/// pipeline, a `DispatchQueue`, or a `Task.detached` runs outside the scope and
/// falls back to the environment's value.
@discardableResult
public func withDependencies<R>(
    _ update: (inout DependencyOverrides) throws -> Void,
    operation: () throws -> R
) rethrows -> R {
    var overrides = DependencyOverrides.current
    try update(&overrides)
    return try DependencyOverrides.$current.withValue(overrides, operation: operation)
}

#if compiler(>=6.4)
/// Runs the asynchronous `operation` with the dependencies that `update` overrides.
///
/// The scope rules are the same as for the synchronous overload.
@discardableResult
public nonisolated(nonsending) func withDependencies<R>(
    _ update: (inout DependencyOverrides) throws -> Void,
    operation: nonisolated(nonsending) () async throws -> R
) async rethrows -> R {
    var overrides = DependencyOverrides.current
    try update(&overrides)
    return try await DependencyOverrides.$current.withValue(overrides, operation: operation)
}
#else
/// Runs the asynchronous `operation` with the dependencies that `update` overrides.
///
/// The scope rules are the same as for the synchronous overload.
@discardableResult
public func withDependencies<R>(
    _ update: (inout DependencyOverrides) throws -> Void,
    operation: () async throws -> R,
    isolation: isolated (any Actor)? = #isolation
) async rethrows -> R {
    var overrides = DependencyOverrides.current
    try update(&overrides)
    return try await DependencyOverrides.$current.withValue(overrides, operation: operation)
}
#endif
