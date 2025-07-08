//
//  DependencyInjectable+MainActor.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 7/8/25.

import Foundation

@MainActor
public protocol MainActorDependencyInjectable {
    associatedtype DependencyType
    static var real: DependencyType { get }
    static var preview: DependencyType { get }
    static var test: DependencyType { get }
}

@MainActor
public extension MainActorDependencyInjectable {
    static var preview: DependencyType { self.real }
    static var test: DependencyType { self.real }
}
