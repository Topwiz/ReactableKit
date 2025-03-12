//
//  NSLock+Extension.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 3/13/25.
//

import Foundation

extension NSRecursiveLock {
    @discardableResult
    func perform<T>(_ block: () -> T) -> T {
        self.lock()
        defer { self.unlock() }
        return block()
    }
}

extension NSLock {
    @discardableResult
    func perform<T>(_ block: () -> T) -> T {
        self.lock()
        defer { self.unlock() }
        return block()
    }
}
