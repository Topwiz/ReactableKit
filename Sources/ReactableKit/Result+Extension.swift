//
//  Result+Extension.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/29/25.
//

import Foundation

public protocol ResultProtocol {
    associatedtype Success
    associatedtype Failure: Error
    
    var output: Success? { get }
    var error: Failure? { get }
}

extension Result: ResultProtocol {
    public var output: Success? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
    
    public var error: Failure? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
