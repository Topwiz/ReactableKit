//
//  Stub.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/21/25.
//

import Foundation

public final class Stub<R: Reactable>: @unchecked Sendable{
    private let reactable: R
    private var canellable: AnyCancellable?
    
    public init(_ reactable: R) {
        self.reactable = reactable
        self.reactable.isStub = true
    }
    
    public lazy var currentState: R.State = self.reactable.initialState
    
    @MainActor
    public func setState(_ state: R.State) {
        self.currentState = state
        self.reactable.setState(state)
    }
    
    @discardableResult
    public func action(_ action: R.Action) async -> R.State {
        var newState = self.currentState
        self.canellable?.cancel()
        return await withUnsafeContinuation { [unowned self] continuation in
            
            self.canellable = self.reactable.mutate(action: action)
                .map { [unowned self] in
                    self.reactable.reduce(state: &newState, mutation: $0)
                }
                .replaceEmpty(with: ())
                .collect()
                .sink { _ in
                    self.currentState = newState
                    continuation.resume(returning: newState)
                }
            
            self.reactable.action(action)
        }
        
    }
    
}
