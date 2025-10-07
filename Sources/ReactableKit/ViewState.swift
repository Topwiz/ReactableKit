//
//  ViewState.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import Combine
import SwiftUI

protocol PublishedWrapper {
    func setOnChange(_ handler: @escaping () -> Void)
}

/// A property wrapper that manages a state value and notifies changes.
/// - Warning: Setting `ignoreEquality` to `true` may cause unnecessary updates to the SwiftUI view.
@propertyWrapper
public final class ViewState<Value: Equatable & Sendable>: @unchecked Sendable, CustomStringConvertible, PublishedWrapper {
    @Atomic private var _value: Value
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

    public init(wrappedValue: Value, ignoreEquality: Bool = false, animation: Animation? = nil) {
        self._value = wrappedValue
        self.ignoreEquality = ignoreEquality
        self.animation = animation
    }
    
    public func setOnChange(_ handler: @escaping () -> Void) {
        self.onChange = handler
    }
    
    public static func == (lhs: ViewState<Value>, rhs: ViewState<Value>) -> Bool {
        lhs._value == rhs._value
    }
}
