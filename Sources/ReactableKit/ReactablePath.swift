//
//  NavigateReactablePath.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/25/25.
//

import Foundation
import SwiftUI

public protocol PathState: Hashable, Sendable { }

public struct AnyPathState: PathState, Hashable, @unchecked Sendable {
    private let base: any PathState
    private let identifier: AnyHashable

    public init<T: PathState>(_ base: T) {
        self.base = base
        self.identifier = UUID()
    }

    public func getBase() -> any PathState {
        return base
    }

    public static func == (lhs: AnyPathState, rhs: AnyPathState) -> Bool {
        lhs.identifier == rhs.identifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

public struct ReactablePath: Hashable {
    private var id: String = UUID().uuidString
    private var path: NavigationPath = .init()
    
    public init() {}
    
    public mutating func append(_ state: any PathState) {
        path.append(AnyPathState(state))
    }
    
    public mutating func removeLast() {
        path.removeLast()
    }
    
    public mutating func removeAll() {
        path = NavigationPath()
    }
    
    public var count: Int {
        path.count
    }
    
    public var navigationPath: NavigationPath {
        get { path }
        set { path = newValue }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}

extension NavigationStack {
    /// Initializes a `NavigationStack` with a `ReactablePath`.
    public init<Content: View, Destination: View>(
        reactablePath: Binding<ReactablePath>,
        @ViewBuilder root: () -> Content,
        @ViewBuilder destination: @escaping (any PathState) -> Destination
    ) where Data == NavigationPath, Root == ModifiedContent<Content, _NavigationDestinationViewModifier<Destination>> {
        self.init(
            path: Binding(
                get: { reactablePath.wrappedValue.navigationPath },
                set: { newPath in
                    var updatedPath = reactablePath.wrappedValue
                    updatedPath.navigationPath = newPath
                    reactablePath.wrappedValue = updatedPath
                }
            )
        ) {
            root()
                .modifier(
                    _NavigationDestinationViewModifier(
                        reactablePath: reactablePath,
                        destination: destination
                    )
                )
        }
    }
}

public struct _NavigationDestinationViewModifier<Destination: View>: ViewModifier {
    private let reactablePath: Binding<ReactablePath>
    private let destination: (any PathState) -> Destination

    public init(
        reactablePath: Binding<ReactablePath>,
        destination: @escaping (any PathState) -> Destination
    ) {
        self.reactablePath = reactablePath
        self.destination = destination
    }

    public func body(content: Content) -> some View {
        content
            .navigationDestination(for: AnyPathState.self) { navigateReactable in
                self.destination(navigateReactable.getBase())
            }
            .navigationDestination(for: LazyAnyPathState.self) { navigateReactable in
                self.destination(navigateReactable.getBase())
            }
    }
}

public extension NavigationLink {
    init<S: PathState>(
        reactable: S,
        @ViewBuilder label: @escaping () -> Label
    ) where Destination == Never {
        self.init(value: AnyPathState(reactable), label: label)
    }
}

// MARK: - LazyAnyPathState

public final class LazyAnyPathState: PathState, Hashable, @unchecked Sendable {
    private let baseClosure: () -> (any PathState)
    private var _cached: WeakWrapper?
    private let identifier: UUID = UUID()
    
    private class WeakWrapper {
        weak var value: AnyObject?
        init(_ value: AnyObject) {
            self.value = value
        }
    }
    
    public init<S: PathState>(_ baseClosure: @escaping () -> S) {
        self.baseClosure = baseClosure
    }
    
    public func getBase() -> any PathState {
        if let cached = self._cached?.value as? any PathState {
            return cached
        } else {
            let newValue = self.baseClosure()
            if let obj = newValue as? AnyObject {
                self._cached = WeakWrapper(obj)
            }
            return newValue
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.identifier)
    }
    
    public static func == (lhs: LazyAnyPathState, rhs: LazyAnyPathState) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

public extension NavigationLink {
    init<S: PathState>(
        reactable: @escaping () -> S,
        @ViewBuilder label: @escaping () -> Label
    ) where Destination == Never {
        self.init(value: LazyAnyPathState(reactable), label: label)
    }
}
