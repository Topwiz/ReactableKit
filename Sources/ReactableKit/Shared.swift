//
//  Shared.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/28/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Storage Type Enum

public enum StorageType: Hashable {
    case userDefaults(UserDefaults = .standard)
    case file(directory: FileManager.SearchPathDirectory = .documentDirectory, path: String? = nil)
    /// Ephemeral in-memory storage. Data is dropped when all references are released.
    case memory
    /// Singleton-like in-memory storage. Data is kept in process even if all references are released,
    /// and the next access will recreate a reference with the last cached value.
    case memorySingleton
    
    var isSingleton: Bool {
        if case .memorySingleton = self { return true }
        if case .userDefaults = self { return true }
        if case .file = self { return false }
        return false
    }
}

// MARK: - @Shared

extension Shared: @unchecked Sendable where Value: Sendable {}

@propertyWrapper
public struct Shared<Value>: CustomStringConvertible {
    private let box: Box
    var key: String { self.reference.key }
    private var reference: any MutableReference<Value> {
        get { box.reference }
        nonmutating set { box.reference = newValue }
    }
    
    public var wrappedValue: Value {
        get { reference.wrappedValue }
        set {
            reference.withLock { $0 = newValue }
        }
    }
    
    public var projectedValue: Shared<Value> { self }
    
    public var description: String {
        "\(self.wrappedValue)"
    }
    
    public var publisher: AnyPublisher<Value, Never> { reference.publisher }
  
    public init(wrappedValue defaultValue: Value, _ storage: StorageType = .memory, key: String? = nil) {
        let prefix = "reactable_shared"
        let inferredKey = key ?? "\(prefix)_\(String(reflecting: Value.self))"

        if (storage == .file() || storage == .userDefaults()) && !(defaultValue is Codable) {
            fatalError("❌ Value must conform to Codable when using .file or .userDefaults storage.")
        }
        
        let managedReference = ManagedMemoryStorage.shared.value(
            forKey: inferredKey,
            storage: storage,
            defaultValue: defaultValue
        )
        
        self.box = Box(managedReference)
    }
    
    init(reference: any MutableReference<Value>) {
        self.box = Box(reference)
    }
    
    /// Perform an operation on shared state with isolated access to the underlying value.
    public func withLock<R>(
        _ operation: (inout Value) throws -> R
    ) rethrows -> R {
        try reference.withLock(operation)
    }
    
    // MARK: - Box Container

    private final class Box: @unchecked Sendable {
        private let lock = NSRecursiveLock()
        private var _reference: any MutableReference<Value>

        var reference: any MutableReference<Value> {
            get {
                lock.withLock { _reference }
            }
            set {
                lock.withLock { _reference = newValue }
            }
        }

        init(_ reference: any MutableReference<Value>) {
            self._reference = reference
        }
    }
}

extension Shared: Equatable where Value: Equatable {
    public static func == (lhs: Shared<Value>, rhs: Shared<Value>) -> Bool {
        func open<T: MutableReference<Value>>(_ lhsReference: T) -> Bool {
            guard lhsReference == rhs.reference as? T else { return false }
            return true
        }
        return open(lhs.reference) && lhs.wrappedValue == rhs.wrappedValue
    }
}
