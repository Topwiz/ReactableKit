//
//  WeakKeyDictionary.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/2/25.
//

import Foundation

// MARK: - WeakKeyDictionary

final class WeakKeyDictionary<Key: AnyObject, Value> {
    private var storage: [WeakReference<Key>: Value] = [:]
    private let lock = NSRecursiveLock()

    init() {}

    func value(forKey key: Key) -> Value? {
        return self.lock.perform {
            let weakKey = WeakReference(key)
            self.installDeallocHook(for: key)
            return self.storage[weakKey]
        }
    }

    func value(forKey key: Key, default defaultValue: @autoclosure () -> Value) -> Value {
        return self.lock.perform {
            let weakKey = WeakReference(key)
            self.installDeallocHook(for: key)
            if let existingValue = self.storage[weakKey] {
                return existingValue
            }
            let newValue = defaultValue()
            self.storage[weakKey] = newValue
            return newValue
        }
    }

    func forceCastedValue<T>(forKey key: Key, default defaultValue: @autoclosure () -> T) -> T {
        let value = self.value(forKey: key, default: defaultValue() as! Value)
        guard let castedValue = value as? T else {
            fatalError("WeakKeyDictionary: Failed to cast value to \(T.self)")
        }
        return castedValue
    }

    func setValue(_ value: Value?, forKey key: Key) {
        self.lock.perform {
            let weakKey = WeakReference(key)
            if let value = value {
                self.storage[weakKey] = value
                self.installDeallocHook(for: key)
            } else {
                self.storage.removeValue(forKey: weakKey)
            }
        }
    }

    // MARK: - Dealloc Hook

    private var deallocHookKey: Void?

    private func installDeallocHook(for key: Key) {
        guard objc_getAssociatedObject(key, &self.deallocHookKey) == nil else { return }

        let weakKey = WeakReference(key)
        let hook = DeallocHook { [weak self] in
            self?.lock.perform {
                self?.storage.removeValue(forKey: weakKey)
            }
        }
        objc_setAssociatedObject(key, &self.deallocHookKey, hook, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

}

extension WeakKeyDictionary {
    var storageCount: Int {
        return self.lock.perform {
            self.storage.count
        }
    }
}

// MARK: - WeakReference

private final class WeakReference<T: AnyObject>: Hashable {
    private let objectHashValue: Int
    weak var object: T?

    init(_ object: T) {
        self.objectHashValue = ObjectIdentifier(object).hashValue
        self.object = object
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.objectHashValue)
    }

    static func == (lhs: WeakReference<T>, rhs: WeakReference<T>) -> Bool {
        return lhs.objectHashValue == rhs.objectHashValue
    }
}

// MARK: - DeallocHook

private final class DeallocHook {
    private let onDeinit: () -> Void

    init(onDeinit: @escaping () -> Void) {
        self.onDeinit = onDeinit
    }

    deinit {
        self.onDeinit()
    }
}
