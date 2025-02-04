//
//  NavigateReactablePath.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/25/25.
//

import Foundation
import SwiftUI

public protocol PathState: Hashable { }

public struct AnyPathState: PathState {
    private let base: any PathState
    private let identifier: AnyHashable

    public init<T: PathState>(_ base: T) {
        self.base = base
        self.identifier = base.hashValue
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


@available(iOS 16.0, *)
public struct ReactablePath: Equatable, Hashable {
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

@available(iOS 16.0, *)
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

@available(iOS 16.0, *)
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
    }
}

@available(iOS 16.0, *)
public extension NavigationLink {
    init<S: PathState>(
        state: S,
        @ViewBuilder label: @escaping () -> Label
    ) where Destination == Never {
        self.init(value: AnyPathState(state), label: label)
    }
}
