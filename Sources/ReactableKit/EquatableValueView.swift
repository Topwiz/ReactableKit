//
//  EquatableValueView.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/13/25.
//

import Foundation
import SwiftUI

struct EquatableValueContentView<Value: Equatable, Content: View>: View, @preconcurrency Equatable {
    let value: Value
    let colorScheme: ColorScheme
    let content: (Value) -> Content

    var body: some View {
        self.content(self.value)
    }

    static func == (lhs: EquatableValueContentView, rhs: EquatableValueContentView) -> Bool {
        lhs.value == rhs.value && lhs.colorScheme == rhs.colorScheme
    }
}

struct EquatableBindingContentView<Value: Equatable, Content: View>: View, @preconcurrency Equatable {
    let value: Binding<Value>
    let colorScheme: ColorScheme
    let content: (Binding<Value>) -> Content

    var body: some View {
        self.content(self.value)
    }

    static func == (lhs: EquatableBindingContentView, rhs: EquatableBindingContentView) -> Bool {
        lhs.value.wrappedValue == rhs.value.wrappedValue && lhs.colorScheme == rhs.colorScheme
    }
}

public struct EquatableValueView<Value: Equatable, Content: View>: View {
    private let content: (Value) -> Content
    private let value: Value

    @Environment(\.colorScheme) private var colorScheme

    public init(value: Value, @ViewBuilder content: @escaping (Value) -> Content) {
        self.content = content
        self.value = value
    }

    public var body: some View {
        EquatableValueContentView(
            value: self.value,
            colorScheme: self.colorScheme,
            content: self.content
        )
    }
}

public struct EquatableBindingView<Value: Equatable, Content: View>: View {
    private let content: (Binding<Value>) -> Content
    private let value: Binding<Value>

    @Environment(\.colorScheme) private var colorScheme

    public init(value: Binding<Value>, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self.content = content
        self.value = value
    }

    public var body: some View {
        EquatableBindingContentView(
            value: self.value,
            colorScheme: self.colorScheme,
            content: self.content
        )
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
            get: {
                self.state[keyPath: keyPath][index]
            },
            set: { newValue in
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
            get: {
                self.state[keyPath: keyPath][index][keyPath: property]
            },
            set: { newValue in
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
    
    /// Updates the UI only when the value associated with a specific key in a dictionary changes.
    /// - Parameters:
    ///   - keyPath: The key path to the dictionary in the state.
    ///   - key: The key whose associated value is observed.
    ///   - content: A closure that receives the value and returns the updated view.
    /// - Returns: A SwiftUI view that updates only when the `value` associated with the given key changes.
    @MainActor
    func updateOn<Key: Hashable, Value: Equatable>(
        _ keyPath: WritableKeyPath<R.State, [Key: Value]>,
        for key: Key,
        @ViewBuilder content: @escaping (Value) -> some View
    ) -> some View {
        guard let value = self.state[keyPath: keyPath][key] else {
            return AnyView(EmptyView())
        }
        return AnyView(EquatableValueView(value: value, content: content))
    }
    
    /// Updates the UI when the value associated with a specific key in a dictionary changes, and allows modification.
    /// - Parameters:
    ///   - keyPath: The key path to the dictionary in the state.
    ///   - key: The key whose associated value is observed and modified.
    ///   - content: A closure that receives the binding to the value and returns the updated view.
    ///   - action: An optional closure that receives `BindingValue<Value>` (old and new values) and returns an action to handle state changes.
    /// - Returns: A SwiftUI view that updates only when the `value` associated with the given key changes and allows modification.
    @MainActor
    func updateOn<Key: Hashable, Value: Equatable>(
        _ keyPath: WritableKeyPath<R.State, [Key: Value]>,
        for key: Key,
        @ViewBuilder content: @escaping (Binding<Value>) -> some View,
        action actionGenerator: (@Sendable (BindingValue<Value>) -> R.Action)? = nil
    ) -> some View {
        guard let existingValue = self.state[keyPath: keyPath][key] else {
            return AnyView(EmptyView())
        }
        
        let binding = Binding<Value>(
            get: {
                self.state[keyPath: keyPath][key] ?? existingValue
            },
            set: { newValue in
                let oldValue = self.state[keyPath: keyPath][key] ?? existingValue
                guard oldValue != newValue else { return }
                self.state[keyPath: keyPath][key] = newValue
                if let action = actionGenerator?(BindingValue(old: oldValue, new: newValue)) {
                    self.reactable.action(action)
                }
            }
        )
        
        return AnyView(EquatableBindingView(value: binding, content: content))
    }
}
