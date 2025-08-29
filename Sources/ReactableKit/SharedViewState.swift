//
//  SharedViewState.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 8/29/25.
//

import Foundation
import Combine
import SwiftUI

@propertyWrapper
public final class SharedViewState<Value: Equatable & Sendable>: @unchecked Sendable, CustomStringConvertible, PublishedWrapper {
    @Shared var _value: Value
    private var ignoreEquality: Bool
    private var onChange: (() -> Void)?
    private var animation: Animation? = nil

    public var wrappedValue: Value {
        get {
            withExtendedLifetime(self) {
                self._value
            }
        }
        set {
            if !self.ignoreEquality {
                guard self._value != newValue else { return }
            }
            self._value = newValue
            let animation = self.animation
            DispatchQueue.main.async {
                if let animation {
                    withAnimation(animation) { self.onChange?() }
                } else {
                    self.onChange?()
                }
            }
        }
    }
    
    public var projectedValue: Binding<Value> {
        Binding(
            get: { self._value },
            set: { self._value = $0 }
        )
    }
    
    public var description: String {
        "\(self.wrappedValue)"
    }

    /// A property wrapper that manages a state value and notifies changes.
    /// - Parameters:
    ///   - ignoreEquality: A Boolean value that indicates whether to ignore equality checks when updating the state. Default is `false`.
    ///   - animation: An optional animation to apply when the state changes. Default is `nil`.
    /// - Warning: Setting `ignoreEquality` to `true` may cause unnecessary updates to the SwiftUI view.
    public init(
        wrappedValue: Value,
        _ storage: StorageType = .memory,
        key: String? = nil,
        ignoreEquality: Bool = false,
        animation: Animation? = nil
    ) {
        self.ignoreEquality = ignoreEquality
        self.animation = animation
        @Shared(storage, key: key) var value: Value = wrappedValue
        self._value = value
    }
    
    public func setOnChange(_ handler: @escaping () -> Void) {
        self.onChange = handler
    }
    
    public static func == (lhs: SharedViewState<Value>, rhs: SharedViewState<Value>) -> Bool {
        lhs._value == rhs._value
    }
    
}

