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
public class ViewState<Value: Equatable>: @unchecked Sendable, Equatable, PublishedWrapper, CustomStringConvertible {
    @Atomic private var value: Value
    private var ignoreEquality: Bool
    private var onChange: (() -> Void)?
    
    public var wrappedValue: Value {
        get { self.value }
        set {
            if !self.ignoreEquality {
                guard newValue != value else { return }
            }
            self.value = newValue
            self.onChange?()
        }
    }
    
    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.value },
            set: { self.value = $0 }
        )
    }
    
    public var description: String {
        "\(self.wrappedValue)"
    }
    
    public init(wrappedValue: Value, ignoreEquality: Bool = false) {
        self.value = wrappedValue
        self.ignoreEquality = ignoreEquality
    }
    
    public func setOnChange(_ handler: @escaping () -> Void) {
        self.onChange = handler
    }
    
    public static func == (lhs: ViewState<Value>, rhs: ViewState<Value>) -> Bool {
        lhs.value == rhs.value
    }
    
}

final class WeakObservableObjectPublisher {
    weak var publisher: ObservableObjectPublisher?

    init(_ publisher: ObservableObjectPublisher?) {
        self.publisher = publisher
    }

    func send() {
        self.publisher?.send()
    }
}
