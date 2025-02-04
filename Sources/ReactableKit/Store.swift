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
    
    private func setup() {
        let mirror = Mirror(reflecting: self.reactable.currentState)
        
        for child in mirror.children {
            if let equatableState = child.value as? PublishedWrapper {
                equatableState.set(objectWillChange: objectWillChange)
            }
        }
    }
    
    @discardableResult
    public func action(_ action: R.Action) async throws -> R.State {
        return try await self.reactable.action(action)
    }
    
    public func action(_ action: R.Action) {
        self.reactable.action(action)
    }
    
    public func action(_ action: R.Action, completion: @escaping (Result<R.State, Error>) -> Void) {
        self.reactable.action(action, completion: completion)
    }
    
    public func binding<Value: Sendable>(
        _ binding: Binding<Value>,
        action actionGenerator: @Sendable @escaping (Value) -> R.Action
    ) -> Binding<Value> where Value: Equatable {
        Binding(
            get: { binding.wrappedValue },
            set: { [weak self] newValue in
                guard let self = self, binding.wrappedValue != newValue else { return }
                binding.wrappedValue = newValue
                let action = actionGenerator(newValue)
                self.reactable.action(action)
            }
        )
    }
}
