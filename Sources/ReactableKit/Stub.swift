//
//  Stub.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/21/25.
//

import Foundation

public final class Stub<R: Reactable> {
    private let reactable: R
    public var actions: [R.Action] = []
    
    public init(_ reactable: R) {
        self.reactable = reactable
        self.reactable.isStub = true
    }
    
    public var currentState: R.State {
        get { self.reactable.currentState }
        set { self.reactable.setState(newValue) }
    }
    
    @discardableResult
    public func action(_ action: R.Action) async -> R.State {
        self.actions.append(action)
        return await self.reactable.action(action)
    }
    
}
