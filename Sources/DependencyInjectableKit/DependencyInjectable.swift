//
//  DependencyInjectable.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/27/25.
//

import Foundation
import SwiftUICore

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
public struct ViewDependency<Value>: DynamicProperty {
    private let keyPath: KeyPath<GlobalDependencyKey, Value>
    @State private var value: Value
    
    public init(_ keyPath: KeyPath<GlobalDependencyKey, Value>) {
        self.keyPath = keyPath
        self.value = GlobalDependencyKey()[keyPath: keyPath]
    }
    
    public var wrappedValue: Value { self.value }
}

@propertyWrapper
public struct LazyViewDependency<Value>: DynamicProperty {
    private let keyPath: KeyPath<GlobalDependencyKey, Value>
    @State private var value: Value?
    
    public init(_ keyPath: KeyPath<GlobalDependencyKey, Value>) {
        self.keyPath = keyPath
        self.value = nil
    }
    
    public var wrappedValue: Value {
        get {
            if let value {
                return value
            }
            let newValue = GlobalDependencyKey()[keyPath: keyPath]
            self.value = newValue
            return newValue
        }
    }
}

@propertyWrapper
public struct Dependency<Value> {
    private let keyPath: KeyPath<GlobalDependencyKey, Value>
    private var value: Value
    
    public init(_ keyPath: KeyPath<GlobalDependencyKey, Value>) {
        self.keyPath = keyPath
        self.value = GlobalDependencyKey()[keyPath: keyPath]
    }
    
    public var wrappedValue: Value { self.value }
}

@propertyWrapper
public struct LazyDependency<Value> {
    private let keyPath: KeyPath<GlobalDependencyKey, Value>
    private var value: Value?
    
    public init(_ keyPath: KeyPath<GlobalDependencyKey, Value>) {
        self.keyPath = keyPath
        self.value = nil
    }
    
    public var wrappedValue: Value {
        mutating get {
            if let value {
                return value
            }
            let newValue = GlobalDependencyKey()[keyPath: keyPath]
            self.value = newValue
            return newValue
        }
    }
}

