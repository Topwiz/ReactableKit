//
//  EquatableValueView.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/13/25.
//

import Foundation
import SwiftUI

struct EquatableValueView<Value: Equatable, Content: View>: View, @preconcurrency Equatable {
    private let content: (Value) -> Content
    private let value: Value

    init(value: Value, @ViewBuilder content: @escaping (Value) -> Content) {
        self.content = content
        self.value = value
    }

    var body: some View {
        content(self.value)
    }

    static func == (lhs: EquatableValueView, rhs: EquatableValueView) -> Bool {
        lhs.value == rhs.value
    }
}

struct EquatableBindingView<Value: Equatable, Content: View>: View, @preconcurrency Equatable {
    private let content: (Binding<Value>) -> Content
    private let value: Binding<Value>

    init(value: Binding<Value>, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self.content = content
        self.value = value
    }

    var body: some View {
        content(self.value)
    }

    static func == (lhs: EquatableBindingView, rhs: EquatableBindingView) -> Bool {
        lhs.value.wrappedValue == rhs.value.wrappedValue
    }
}


public extension Store {

    /// Updates the UI when the specified state value changes.
    /// - Parameters:
    ///   - keyPath: The key path to the state value.
    ///   - content: A closure that returns the updated view when the value changes.
    /// - Returns: A SwiftUI view that updates only when the value changes.
    @MainActor
    func updateOn<Value: Equatable>(
        _ keyPath: KeyPath<R.State, Value>,
        @ViewBuilder content: @escaping (Value) -> some View
    ) -> some View {
        let binding = self.state[keyPath: keyPath]
        return EquatableValueView(value: binding, content: content)
    }

    /// Updates the UI when a `Binding<Value>` changes and optionally triggers an action.
    /// - Parameters:
    ///   - keyPath: The key path to the state binding.
    ///   - action: An optional closure that receives `BindingValue<Value>` and returns an action.
    ///   - content: A closure that receives the binding and returns the updated view.
    /// - Returns: A SwiftUI view that updates only when the binding changes.
    @MainActor
    func updateOn<Value: Equatable>(
        _ keyPath: WritableKeyPath<R.State, Value>,
        @ViewBuilder content: @escaping (Binding<Value>) -> some View,
        action actionGenerator: (@Sendable (BindingValue<Value>) -> R.Action)? = nil
    ) -> some View {
        let binding = self.binding(keyPath, action: actionGenerator)
        return EquatableBindingView(value: binding, content: content)
    }

    /// Updates the UI when a specific item in a list changes.
    /// - Parameters:
    ///   - keyPath: The key path to the list of state values.
    ///   - id: The `id` of the item to update.
    ///   - content: A closure that returns the updated view when the item changes.
    /// - Returns: A SwiftUI view that updates only when the selected item changes.
    @MainActor
    func updateOn<T: Identifiable & Equatable>(
        _ keyPath: WritableKeyPath<R.State, [T]>,
        for id: T.ID,
        @ViewBuilder content: @escaping (T) -> some View
    ) -> some View {
        guard let index = self.state[keyPath: keyPath].firstIndex(where: { $0.id == id }) else {
            return AnyView(EmptyView())
        }
        let binding = self.state[keyPath: keyPath][index]
        return AnyView(EquatableValueView(value: binding, content: content))
    }

    /// Updates the UI when a specific item in a list changes and allows modification.
    /// - Parameters:
    ///   - keyPath: The key path to the list of state values.
    ///   - id: The `id` of the item to update.
    ///   - content: A closure that returns the updated view when the item changes.
    ///   - action: An optional closure that receives `BindingValue<T>` and returns an action.
    /// - Returns: A SwiftUI view that updates only when the selected item changes and allows editing.
    @MainActor
    func updateOn<T: Identifiable & Equatable>(
        _ keyPath: WritableKeyPath<R.State, [T]>,
        for id: T.ID,
        @ViewBuilder content: @escaping (Binding<T>) -> some View,
        action actionGenerator: (@Sendable (BindingValue<T>) -> R.Action)? = nil
    ) -> some View {
        guard let index = self.state[keyPath: keyPath].firstIndex(where: { $0.id == id }) else {
            return AnyView(EmptyView())
        }

        let binding = Binding<T>(
            get: { self.state[keyPath: keyPath][index] },
            set: { [weak self] newValue in
                guard let self = self else { return }
                let oldValue = self.state[keyPath: keyPath][index]
                guard oldValue != newValue else { return }
                self.state[keyPath: keyPath][index] = newValue
                if let action = actionGenerator?(BindingValue(old: oldValue, new: newValue)) {
                    self.reactable.action(action)
                }
            }
        )

        return AnyView(EquatableBindingView(value: binding, content: content))
    }

    /// Updates the UI when a specific property of an item in a list changes.
    /// - Parameters:
    ///   - keyPath: The key path to the list of state values.
    ///   - id: The `id` of the item to update.
    ///   - property: The property of the item to observe.
    ///   - content: A closure that returns the updated view when the property changes.
    /// - Returns: A SwiftUI view that updates only when the selected property changes.
    @MainActor
    func updateOn<T: Identifiable & Equatable, Value: Equatable>(
        _ keyPath: WritableKeyPath<R.State, [T]>,
        for id: T.ID,
        property: WritableKeyPath<T, Value>,
        @ViewBuilder content: @escaping (Value) -> some View
    ) -> some View {
        guard let index = self.state[keyPath: keyPath].firstIndex(where: { $0.id == id }) else {
            return AnyView(EmptyView())
        }
        let binding = self.state[keyPath: keyPath][index][keyPath: property]
        return AnyView(EquatableValueView(value: binding, content: content))
    }

    /// Updates the UI when a `Binding` to a specific property of an item in a list changes.
    /// - Parameters:
    ///   - keyPath: The key path to the list of state values.
    ///   - id: The `id` of the item to update.
    ///   - property: The property of the item to observe and modify.
    ///   - action: An optional closure that receives `BindingValue<T>` and returns an action.
    ///   - content: A closure that receives the binding and returns the updated view.
    /// - Returns: A SwiftUI view that updates only when the selected property changes and allows modification.
    @MainActor
    func updateOn<T: Identifiable & Equatable, Value: Equatable>(
        _ keyPath: WritableKeyPath<R.State, [T]>,
        for id: T.ID,
        property: WritableKeyPath<T, Value>,
        @ViewBuilder content: @escaping (Binding<Value>) -> some View,
        action actionGenerator: (@Sendable (BindingValue<Value>) -> R.Action)? = nil
    ) -> some View {
        guard let index = self.state[keyPath: keyPath].firstIndex(where: { $0.id == id }) else {
            return AnyView(EmptyView())
        }

        let binding = Binding<Value>(
            get: { self.state[keyPath: keyPath][index][keyPath: property] },
            set: { [weak self] newValue in
                guard let self = self else { return }
                let oldValue = self.state[keyPath: keyPath][index][keyPath: property]
                guard oldValue != newValue else { return }
                self.state[keyPath: keyPath][index][keyPath: property] = newValue
                if let action = actionGenerator?(BindingValue(old: oldValue, new: newValue)) {
                    self.reactable.action(action)
                }
            }
        )

        return AnyView(EquatableBindingView(value: binding, content: content))
    }
}
