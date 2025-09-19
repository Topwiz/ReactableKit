//
//  DependencyInjectable.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/27/25.
//

import Foundation
import SwiftUI

@MainActor
public protocol MainActorDependencyInjectable {
    associatedtype DependencyType
    static var real: DependencyType { get }
    static var preview: DependencyType { get }
    static var test: DependencyType { get }
}

public extension MainActorDependencyInjectable {
    static var preview: DependencyType { self.real }
    static var test: DependencyType { self.real }
}

@MainActor
@propertyWrapper
public struct MainActorDependency<Value>: @unchecked Sendable {
    private let keyPath: KeyPath<GlobalDependencyKey, Value>
    private var value: Value
    
    public init(_ keyPath: KeyPath<GlobalDependencyKey, Value>) {
        self.keyPath = keyPath
        self.value = GlobalDependencyKey()[keyPath: keyPath]
    }
    
    public var wrappedValue: Value { self.value }
}

public protocol DependencyInjectable {
    associatedtype DependencyType
    static var real: DependencyType { get }
    static var preview: DependencyType { get }
    static var test: DependencyType { get }
}

public extension DependencyInjectable {
    static var preview: DependencyType { self.real }
    static var test: DependencyType { self.real }
}

@propertyWrapper
public struct Dependency<Value>: DynamicProperty {
    private let keyPath: KeyPath<GlobalDependencyKey, Value>
    @State private var value: Value
    
    public init(_ keyPath: KeyPath<GlobalDependencyKey, Value>) {
        self.keyPath = keyPath
        self.value = GlobalDependencyKey()[keyPath: keyPath]
    }
    
    public var wrappedValue: Value { self.value }
}
