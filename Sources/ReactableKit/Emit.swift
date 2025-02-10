//
//  Emit.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/6/25.
//

import Foundation

@propertyWrapper
public struct Emit<Value>: CustomStringConvertible {
    
    public var value: Value {
        didSet {
            self.increaseCount()
        }
    }
    
    public internal(set) var count = 0
    
    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }
    
    public var wrappedValue: Value {
        get { self.value }
        set { self.value = newValue }
    }
    
    public var projectedValue: Self {
        self
    }
    
    public var description: String {
        "\(self.wrappedValue)"
    }
    
    private mutating func increaseCount() {
        self.count &+= 1
    }
}

extension Emit: Equatable where Value: Equatable {
    public static func == (lhs: Emit<Value>, rhs: Emit<Value>) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}

extension Reactable {
    public func emit<T>(_ keyPath: KeyPath<State, Emit<T>>) -> AnyPublisher<T, Never> {
        self.state
            .map { $0[keyPath: keyPath] }
            .removeDuplicates { $0.count == $1.count }
            .map(\.wrappedValue)
            .eraseToAnyPublisher()
    }
}

extension Store {
    public func emit<T>(_ keyPath: KeyPath<R.State, Emit<T>>) -> AnyPublisher<T, Never> {
        self.publisher
            .map { $0[keyPath: keyPath] }
            .removeDuplicates { $0.count == $1.count }
            .map(\.wrappedValue)
            .eraseToAnyPublisher()
    }
}
