//
//  Reactable.swift
//  Reactable
//
//  Created by Jeehoon Son on 1/23/25.
//

import SwiftUI
@_exported import Combine

enum WeakCache {
    nonisolated(unsafe) static let queue = WeakKeyDictionary<AnyObject, DispatchQueue>()
    nonisolated(unsafe) static let cancellables = WeakKeyDictionary<AnyObject, Set<AnyCancellable>>()
    nonisolated(unsafe) static let state = WeakKeyDictionary<AnyObject, Any>()
    nonisolated(unsafe) static let currentState = WeakKeyDictionary<AnyObject, Any>()
    nonisolated(unsafe) static let isTransformRegisteredKey = WeakKeyDictionary<AnyObject, Any>()
}

public protocol Reactable: AnyObject, IdentityHashable {
    associatedtype Action
    associatedtype State: Sendable
    associatedtype Mutation
    
    var initialState: State { get }
    var state: AnyPublisher<State, Never> { get }
    var currentState: State { get }
    var queue: DispatchQueue { get set }
    var cancellables: Set<AnyCancellable> { get set }
    
    func action(_ action: Action) async -> State
    func mutate(action: Action) -> AnyPublisher<Mutation, Never>
    func reduce(state: inout State, mutate: Mutation)
    func registerTransform()
    func transformAction() -> AnyPublisher<Action, Never>
}

public extension Reactable {
    
    var state: AnyPublisher<State, Never> {
        WeakCache.state.forceCastedValue(forKey: self, default: self.createStream()).eraseToAnyPublisher()
    }
    
    var currentState: State {
        WeakCache.currentState.forceCastedValue(forKey: self, default: self.initialState)
    }
    
    var queue: DispatchQueue {
        get { WeakCache.queue.forceCastedValue(forKey: self, default: .main) }
        set { WeakCache.queue.setValue(newValue, forKey: self) }
    }
    
    var cancellables: Set<AnyCancellable> {
        get { WeakCache.cancellables.forceCastedValue(forKey: self, default: []) }
        set { WeakCache.cancellables.setValue(newValue, forKey: self) }
    }
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        Empty<Mutation, Never>().eraseToAnyPublisher()
    }
    
    func reduce(state: inout State, mutate: Mutation) { }
    
    func transformAction() -> AnyPublisher<Action, Never> {
        Empty<Action, Never>().eraseToAnyPublisher()
    }
    
    internal func setState(_ state: State) {
        WeakCache.currentState.setValue(state, forKey: self)
        let subject = WeakCache.state.forceCastedValue(forKey: self, default: self.createStream())
        subject.send(state)
    }
    
    internal func createStream() -> CurrentValueSubject<State, Never> {
        let stateStream = CurrentValueSubject<State, Never>(self.initialState)
        return stateStream
    }
}

public extension Reactable {

    func action(_ action: Action) {
        self.dispatch(action: action, completion: { _ in })
    }
    
    func action(_ action: Action, completion: @escaping (Result<State, Never>) -> Void) {
        self.dispatch(action: action, completion: completion)
    }
    
    @discardableResult
    func action(_ action: Action) async -> State {
        return await withUnsafeContinuation { [unowned self] continuation in
            self.dispatch(action: action) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let state):
                    continuation.resume(returning: state)
                    
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func actionPublish(_ action: Action) -> AnyPublisher<State, Never> {
        Future { [unowned self] promise in
            self.dispatch(action: action) { [weak self] result in
                guard let self else { return }
                if let state = result.output {
                    promise(.success(state))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    internal func dispatch(action: Action, completion: @escaping (Result<State, Never>) -> Void) {
        var cancellable: AnyCancellable? = nil
        
        cancellable = self.mutate(action: action)
            .receive(on: self.queue)
            .scan(self.currentState) { [weak self] currentState, mutation -> State in
                guard let self else { return currentState }
                var newState = self.currentState
                self.reduce(state: &newState, mutate: mutation)
                self.setState(newState)
                return newState
            }
            .last()
            .replaceEmpty(with: self.currentState)
            .sink(
                receiveCompletion: { [weak self] completionResult in
                    guard let self, let cancellable else { return }
                    self.cancellables.remove(cancellable)
                },
                receiveValue: { [weak self] finalState in
                    guard let self else { return }
                    completion(.success(finalState))
                    self.sendGlobalActionIfNeeded(action, state: finalState)
                }
            )
        
        if let cancellable {
            cancellables.insert(cancellable)
        }
    }
    
    func registerTransform() {
        guard !self.isTransformRegistered else { return }
        self.isTransformRegistered = true
        
        let transformedActions = self.transformAction()
            .receive(on: self.queue)
            .share()
        
        let mutationPublisher = transformedActions
            .flatMap { [weak self] action -> AnyPublisher<Mutation, Never> in
                guard let self = self else {
                    return Empty<Mutation, Never>().eraseToAnyPublisher()
                }
                return self.mutate(action: action)
                    .eraseToAnyPublisher()
            }
        
        let cancellable = mutationPublisher
            .sink(receiveValue: { [weak self] mutation in
                guard let self = self else { return }
                var currentState = self.currentState
                self.reduce(state: &currentState, mutate: mutation)
                self.setState(currentState)
            })
        
        cancellable.store(in: &cancellables)
    }
    
    private var isTransformRegisteredKey: KeyWrapper {
        get { WeakCache.isTransformRegisteredKey.forceCastedValue(forKey: self, default: KeyWrapper()) }
        set { WeakCache.isTransformRegisteredKey.setValue(newValue, forKey: self) }
    }
    
    var isTransformRegistered: Bool {
        get {
            objc_getAssociatedObject(self, isTransformRegisteredKey.pointer) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, isTransformRegisteredKey.pointer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

final class KeyWrapper {
    let pointer: UnsafeRawPointer = UnsafeRawPointer(bitPattern: 0x1)!
    init() { }
}
