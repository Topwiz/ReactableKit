//
//  Atomic.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation

@propertyWrapper
public struct Atomic<Value> {
    private var value: Value
    private let lock = NSLock()

    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    public var wrappedValue: Value {
        get {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.value
        }
        set {
            self.lock.lock()
            defer { self.lock.unlock() }
            self.value = newValue
        }
    }
}
