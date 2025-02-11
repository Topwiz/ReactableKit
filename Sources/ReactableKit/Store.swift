//
//  File.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import Combine
import SwiftUI

public class Store<R: Reactable>: @unchecked Sendable, ObservableObject {
    private let reactable: R
    
    public var state: R.State {
        get { self.reactable.currentState }
        set { self.reactable.setState(newValue) }
    }
    
    public var projectedValue: Binding<R.State> {
        Binding(
            get: { self.reactable.currentState },
            set: { self.reactable.setState($0) }
        )
    }
    
    public init(create: @escaping () -> R) {
        self.reactable = create()
        self.setup()
        self.reactable.registerTransform()
    }
    
    public init(_ create: R) {
        self.reactable = create
        self.setup()
        self.reactable.registerTransform()
    }
    
    public var publisher: AnyPublisher<R.State, Never> {
        self.reactable.state
    }
    
    private func setup() {
        let mirror = Mirror(reflecting: self.reactable.currentState)
        
        for child in mirror.children {
            if let equatableState = child.value as? PublishedWrapper {
                equatableState.set(objectWillChange: objectWillChange)
            }
        }
    }
    
    @discardableResult
    public func action(_ action: R.Action) async -> R.State {
        return await self.reactable.action(action)
    }
    
    public func action(_ action: R.Action) {
        self.reactable.action(action)
    }
    
    public func action(_ action: R.Action, completion: @escaping (Result<R.State, Never>) -> Void) {
        self.reactable.action(action, completion: completion)
    }
    
    public func binding<Value: Equatable>(
        _ keyPath: WritableKeyPath<R.State, Value>,
        action actionGenerator: (@Sendable (BindingValue<Value>) -> R.Action)? = nil
    ) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { newValue in
                guard self.state[keyPath: keyPath] != newValue else { return }
                let oldValue = self.state[keyPath: keyPath]
                self.state[keyPath: keyPath] = newValue
                if let action = actionGenerator?(BindingValue(old: oldValue, new: newValue)) {
                    self.reactable.action(action)
                }
            }
        )
    }
}

extension KeyPath: @unchecked Sendable {}

public struct BindingValue<Value: Equatable> {
    public let old: Value
    public let new: Value
}
