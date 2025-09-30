//
//  Emit.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/6/25.
//

import Foundation
import SwiftUI

extension Emit: @unchecked Sendable where Value: Sendable {}

@propertyWrapper
public struct Emit<Value>: CustomStringConvertible {
    
    public var value: Value {
        didSet { self.increaseCount() }
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
        let startCount = self.state[keyPath: keyPath].count
        return self.publisher
            .map { $0[keyPath: keyPath] }
            .removeDuplicates { $0.count == $1.count }
            .drop(while: { $0.count == startCount })
            .map(\.wrappedValue)
            .eraseToAnyPublisher()
    }
}

extension View {
    public func emit<R: Reactable, T: Sendable>(
        _ keyPath: KeyPath<R.State, Emit<T>>,
        from store: Store<R>,
        perform action: @escaping (T) -> Void
    ) -> some View {
        self.modifier(EmitModifier(keyPath: keyPath, store: store, action: action))
    }
}

private struct EmitModifier<R: Reactable, T: Sendable>: ViewModifier {
    let keyPath: KeyPath<R.State, Emit<T>>
    let store: Store<R>
    let action: (T) -> Void
    
    @State private var cancellable: AnyCancellable?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                self.cancellable = self.store.emit(self.keyPath)
                    .receive(on: DispatchQueue.main)
                    .bind(to: self.action)
            }
            .onDisappear {
                self.cancellable?.cancel()
                self.cancellable = nil
            }
    }
}
