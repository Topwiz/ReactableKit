//
//  StrongKeyDictionary.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/3/25.
//

import Foundation

enum Cache {
    nonisolated(unsafe) static let sharedProperty = StrongKeyDictionary<String, Any>()
    nonisolated(unsafe) static let observableEvent = StrongKeyDictionary<String, Any>()
}

final class StrongKeyDictionary<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]
    private let lock = NSRecursiveLock()
    
    init() {}

    func value(forKey key: Key) -> Value? {

        lock.lock()
        defer { lock.unlock() }
        
        return storage[key]
    }

    func value(forKey key: Key, default defaultValue: @autoclosure () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }

        if let existingValue = storage[key] {
            return existingValue
        }

        let newValue = defaultValue()
        storage[key] = newValue
        return newValue
    }
    
    func forceCastedValue<T>(forKey key: Key, default defaultValue: @autoclosure () -> T) -> T {
        let value = self.value(forKey: key, default: defaultValue() as! Value)
        guard let castedValue = value as? T else {
            fatalError("StrongKeyDictionary: Failed to cast value to \(T.self)")
        }
        return castedValue
    }

    func setValue(_ value: Value?, forKey key: Key) {
        lock.lock()
        defer { lock.unlock() }

        if let value = value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }
}
