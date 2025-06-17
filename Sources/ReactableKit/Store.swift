//
//  File.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
public class Store<R: Reactable>: ObservableObject, @unchecked Sendable {
    public let reactable: R
    
    public var state: R.State {
        get { self.reactable.currentState }
        set { self.reactable.setState(newValue) }
    }
    
    var publisher: AnyPublisher<R.State, Never> {
        self.reactable.state
    }

    private var cancellables = Set<AnyCancellable>()

    public init(create: @escaping () -> R) {
        self.reactable = create()
        self.setup()
        self.reactable.initialize()
    }

    public init(_ create: R) {
        self.reactable = create
        self.setup()
        self.reactable.initialize()
    }

    private func setup() {
        let mirror = Mirror(reflecting: self.reactable.currentState)
        
        for child in mirror.children {
            if let publishedWrapper = child.value as? PublishedWrapper {
                DispatchQueue.main.async { [weak self] in
                    publishedWrapper.setOnChange { [weak self] in
                        DispatchQueue.main.async { [weak self] in
                            self?.objectWillChange.send()
                        }
                    }
                }
            }
        }
    }
    
    public func action(_ action: R.Action) {
        self.reactable.action(action)
    }

    public func binding<Value: Equatable>(
        _ keyPath: WritableKeyPath<R.State, Value>,
        action actionGenerator: (@MainActor @Sendable (BindingValue<Value>) -> R.Action?)? = nil
    ) -> Binding<Value> {
        Binding(
            get: {
                self.state[keyPath: keyPath]
            },
            set: { newValue in
                guard self.state[keyPath: keyPath] != newValue else { return }
                let oldValue = self.state[keyPath: keyPath]
                self.state[keyPath: keyPath] = newValue
                if let action = actionGenerator?(BindingValue(old: oldValue, new: newValue)) {
                    self.action(action)
                }
            }
        )
    }
}

public struct BindingValue<Value: Equatable> {
    public let old: Value
    public let new: Value
}
