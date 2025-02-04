//
//  IdentifierHashable.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation

public protocol IdentityHashable: AnyObject, Hashable { }

public extension IdentityHashable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs === rhs
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self).hashValue)
    }
}
