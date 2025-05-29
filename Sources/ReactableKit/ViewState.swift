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

@propertyWrapper
public final class ViewState<Value: Equatable>: @unchecked Sendable, CustomStringConvertible, PublishedWrapper {
    @Atomic private var _value: Value
    private var ignoreEquality: Bool
    private var onChange: (() -> Void)?

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
            DispatchQueue.main.async {
                self.onChange?()
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
    /// - Warning: Setting `ignoreEquality` to `true` may cause unnecessary updates to the SwiftUI view.
    public init(wrappedValue: Value, ignoreEquality: Bool = false) {
        self._value = wrappedValue
        self.ignoreEquality = ignoreEquality
    }
    
    public func setOnChange(_ handler: @escaping () -> Void) {
        self.onChange = handler
    }
    
    public static func == (lhs: ViewState<Value>, rhs: ViewState<Value>) -> Bool {
        lhs._value == rhs._value
    }
    
}
