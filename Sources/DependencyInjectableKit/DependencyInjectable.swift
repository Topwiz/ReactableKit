//
//  DependencyInjectable.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/27/25.
//

import Foundation
import SwiftUI

public protocol DependencyInjectable {
    associatedtype DependencyType
    static var real: DependencyType { get }
    static var preview: DependencyType { get }
    static var test: DependencyType { get }
}

public extension DependencyInjectable {
    static var preview: DependencyType { self.real }
    static var test: DependencyType { self.real }
}

@attached(peer, names: arbitrary)
@attached(accessor)
public macro Dependency<Value>(_ keyPath: KeyPath<GlobalDependencyKey, Value>) = #externalMacro(
    module: "DependencyInjectableMacros",
    type: "DependencyMacro"
)

/// The local-scope half of `@Dependency`.
///
/// The attached macro expands to an instance stored property, so it can only be
/// applied where a type can hold one. A property wrapper of the same name covers
/// every local declaration — function bodies, initializers, closures, and
/// accessor bodies, implicit ones included. The compiler takes the macro where
/// member storage is valid and this wrapper everywhere else.
///
/// Both own a `DependencyStorage`, so the two behave identically: resolution is
/// deferred to first access, guarded by that storage's own lock, and cached for
/// the lifetime of the declaration. The wrapper additionally infers `Value` from
/// the key path, so the annotation the macro requires is optional here.
@propertyWrapper
public struct Dependency<Value> {
    private let storage: DependencyStorage<Value>

    public init(_ keyPath: KeyPath<GlobalDependencyKey, Value>) {
        self.storage = DependencyStorage(keyPath)
    }

    public var wrappedValue: Value { self.storage.value }
}

public struct DependencyStorage<Value> {
    private let box: Box

    public init(_ keyPath: KeyPath<GlobalDependencyKey, Value>) {
        self.box = Box(keyPath)
    }

    public var value: Value { self.box.value }

    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private let keyPath: KeyPath<GlobalDependencyKey, Value>
        private var cached: Value?

        init(_ keyPath: KeyPath<GlobalDependencyKey, Value>) {
            self.keyPath = keyPath
        }

        var value: Value {
            self.lock.lock()
            defer { self.lock.unlock() }
            if let cached = self.cached {
                return cached
            }
            let resolved = GlobalDependencyKey()[keyPath: self.keyPath]
            self.cached = resolved
            return resolved
        }
    }
}

extension DependencyStorage: Sendable where Value: Sendable {}

@MainActor
@propertyWrapper
public struct ViewDependency<Value>: DynamicProperty {
    private let keyPath: KeyPath<GlobalDependencyKey, Value>
    @State private var value: Value

    public init(_ keyPath: KeyPath<GlobalDependencyKey, Value>) {
        self.keyPath = keyPath
        self.value = GlobalDependencyKey()[keyPath: keyPath]
    }

    public var wrappedValue: Value { self.value }
}

@MainActor
@propertyWrapper
public struct LazyViewDependency<Value>: DynamicProperty {
    private let keyPath: KeyPath<GlobalDependencyKey, Value>
    @State private var value: Value?

    public init(_ keyPath: KeyPath<GlobalDependencyKey, Value>) {
        self.keyPath = keyPath
        self.value = nil
    }

    public var wrappedValue: Value {
        get {
            if let value {
                return value
            }
            let newValue = GlobalDependencyKey()[keyPath: keyPath]
            self.value = newValue
            return newValue
        }
    }
}
