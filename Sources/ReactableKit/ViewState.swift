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
    var objectWillChange: WeakObservableObjectPublisher? { get set }
    func set(objectWillChange: ObservableObjectPublisher)
}

@propertyWrapper
public class ViewState<Value: Equatable>: @unchecked Sendable, Equatable, PublishedWrapper {
    @Atomic private var value: Value
    private var ignoreEquality: Bool
    var objectWillChange: WeakObservableObjectPublisher?
    
    public var wrappedValue: Value {
        get { value }
        set {
            if !self.ignoreEquality {
                guard newValue != value else { return }
            }
            value = newValue
            self.update()
        }
    }
    
    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.value },
            set: { self.value = $0 }
        )
    }
    
    func update() {
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange?.send()
        }
    }
    
    public init(wrappedValue: Value, ignoreEquality: Bool = false) {
        self.value = wrappedValue
        self.ignoreEquality = ignoreEquality
    }

    func set(objectWillChange: ObservableObjectPublisher) {
        self.objectWillChange = .init(objectWillChange)
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
        publisher?.send()
    }
}
