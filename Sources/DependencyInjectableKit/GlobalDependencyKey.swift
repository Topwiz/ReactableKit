//
//  GlobalDependencyKey.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 3/6/25.
//

import Foundation

public enum AppEnvironment {
    case real
    case preview
    case test
    
    static var current: AppEnvironment {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return .preview
        } else if NSClassFromString("XCTest") != nil {
            return .test
        }
        return .real
    }
}

public struct GlobalDependencyKey: Sendable {
    public static var appEnvironment: AppEnvironment { .current }
    
    public subscript<T: DependencyInjectable>(_: T.Type) -> T.DependencyType {
        switch GlobalDependencyKey.appEnvironment {
        case .real:
            return T.real
        case .preview:
            return T.preview
        case .test:
            return T.test
        }
    }
    
    public init() {}
}
