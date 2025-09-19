//
//  AsyncStore.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/24/25.
//

import SwiftUI
import Combine

@MainActor
public class Store<R: Reactable>: ObservableObject {
    public let reactable: R
    
    public var state: R.State {
        get { self.reactable.state }
        set { self.reactable.state = newValue }
    }
    
    var publisher: AnyPublisher<R.State, Never> {
        self.reactable.statePublisher
    }

    private var cancellables = Set<AnyCancellable>()
    
    public init(create: @escaping () -> R) {
        self.reactable = create()
        self.setupViewStateObservers(for: self.reactable.initialState)
        self.reactable.initialize()
    }
    
    public init(_ reactable: R) {
        self.reactable = reactable
        self.setupViewStateObservers(for: reactable.initialState)
        reactable.initialize()
    }
    
    private func setupViewStateObservers(for state: R.State) {
        let mirror = Mirror(reflecting: state)
        for child in mirror.children {
            if let publishedWrapper = child.value as? PublishedWrapper {
                publishedWrapper.setOnChange { [weak self] in
                    self?.objectWillChange.send()
                }
            }
        }
    }
    
    // MARK: - Action Methods
    
    @discardableResult
    public func action(_ action: R.Action) async -> R.State {
        await self.reactable.action(action)
    }
    
    public func action(_ action: R.Action) {
        self.reactable.action(action)
    }
    
    // MARK: - Binding Support
    
    public func binding<Value: Equatable>(
        _ keyPath: WritableKeyPath<R.State, Value>,
        action actionGenerator: (@MainActor @Sendable (BindingValue<Value>) -> R.Action?)? = nil
    ) -> Binding<Value> {
        Binding(
            get: {
                self.state[keyPath: keyPath]
            },
            set: { newValue in
                let oldValue = self.state[keyPath: keyPath]
                guard oldValue != newValue else { return }
                self.state[keyPath: keyPath] = newValue
                if let action = actionGenerator?(BindingValue(old: oldValue, new: newValue)) {
                    Task {
                        await self.action(action)
                    }
                }
            }
        )
    }
}


public struct BindingValue<Value: Equatable> {
    public let old: Value
    public let new: Value
}
