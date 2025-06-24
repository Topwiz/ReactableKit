//
//  Reactable.swift
//  Reactable
//
//  Created by Jeehoon Son on 1/23/25.
//

import SwiftUI
@_exported import Combine

private enum WeakCache {
    nonisolated(unsafe) static let queue = WeakKeyDictionary<AnyObject, DispatchQueue>()
    nonisolated(unsafe) static let cancellables = WeakKeyDictionary<AnyObject, Set<AnyCancellable>>()
    nonisolated(unsafe) static let stream = WeakKeyDictionary<AnyObject, Any>()
    nonisolated(unsafe) static let currentState = WeakKeyDictionary<AnyObject, Any>()
    nonisolated(unsafe) static let isStub = WeakKeyDictionary<AnyObject, Bool>()
    nonisolated(unsafe) static let completion = WeakKeyDictionary<AnyObject, Any>()
    nonisolated(unsafe) static let resultSubject = WeakKeyDictionary<AnyObject, Any>()
}

public protocol Reactable: AnyObject, IdentityHashable {
    associatedtype Action: Sendable
    associatedtype Mutation: Sendable
    associatedtype State: Sendable
    typealias AsyncMutation = (Mutation) async -> Void
    
    var initialState: State { get }
    var state: AnyPublisher<State, Never> { get }
    var currentState: State { get }
    var queue: DispatchQueue { get set }
    var cancellables: Set<AnyCancellable> { get set }
    var resultSubject: PassthroughSubject<ObservableEventResult<Self>, Never> { get set }
    
    func initialize()
    func action(_ action: Action)
    func mutate(action: Action) -> AnyPublisher<Mutation, Never>
    func reduce(state: inout State, mutation: Mutation)
    func transformAction() -> AnyPublisher<Action, Never>
}

public extension Reactable {
    
    private var stream: Stream<Action, State> {
        WeakCache.stream.forceCastedValue(forKey: self, default: self.createStream())
    }
    
    var state: AnyPublisher<State, Never> {
        self.stream.state.publisher()
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
    
    var resultSubject: PassthroughSubject<ObservableEventResult<Self>, Never> {
        get { WeakCache.resultSubject.forceCastedValue(forKey: self, default: .init()) }
        set { WeakCache.resultSubject.setValue(newValue, forKey: self) }
    }
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        Empty<Mutation, Never>().eraseToAnyPublisher()
    }
    
    func reduce(state: inout State, mutation: Mutation) { }
    
    func transformAction() -> AnyPublisher<Action, Never> {
        .empty()
    }
    
    func initialize() {
        _ = self.state
    }
    
    @MainActor
    internal func setState(_ state: State) {
        WeakCache.currentState.setValue(state, forKey: self)
    }
}

public extension Reactable {
    
    func action(_ action: Action) {
        let stream = self.stream
        self.queue.async {
            stream.action.send(action)
        }
    }
    
    private func createStream() -> Stream<Action, State> {
        let actionSubject = PassthroughSubject<Action, Never>()
        let stateSubject = ReplaySubject<State, Never>(bufferSize: 1)

        let transformedActionStream = self.transformAction()
            .eraseToAnyPublisher()

        let mergedActionStream = Publishers.Merge(
            actionSubject.eraseToAnyPublisher(),
            transformedActionStream
        )
            .receive(on: self.queue)

        let mutationStream = mergedActionStream
            .flatMap { [weak self] action -> AnyPublisher<(Action, Mutation), Never> in
                guard let self = self else {
                    return Empty<(Action, Mutation), Never>().eraseToAnyPublisher()
                }
                return self.mutate(action: action)
                    .receive(on: self.queue)
                    .map { (action, $0) }
                    .handleEvents(receiveCompletion: { [weak self] completion in
                        guard let self else { return }
                        if case .finished = completion {
                            self.sendGlobalActionIfNeeded(action, state: self.currentState)
                        }
                    })
                    .eraseToAnyPublisher()
            }

        let stateStream = mutationStream
            .scan((nil as Action?, self.initialState)) { [weak self] acc, tuple in
                guard let self else { return acc }
                let (_, prevState) = acc
                let (action, mutation) = tuple
                var newState = prevState
                self.reduce(state: &newState, mutation: mutation)
                return (action, newState)
            }
            .handleEvents(receiveOutput: { [weak self] (action, newState) in
                guard let self else { return }
                WeakCache.currentState.setValue(newState, forKey: self)
            })
            .map { $0.1 }
            .eraseToAnyPublisher()

        stateStream
            .sink(receiveValue: stateSubject.send)
            .store(in: &self.cancellables)

        return Stream(action: actionSubject, state: stateSubject)
    }
}

// MARK: - Stub

public extension Reactable {
    var isStub: Bool {
        get { WeakCache.isStub.forceCastedValue(forKey: self, default: false) }
        set { WeakCache.isStub.setValue(newValue, forKey: self) }
    }
}

struct Stream<A: Sendable, S: Sendable>: Sendable {
    var action: PassthroughSubject<A, Never>
    var state: ReplaySubject<S, Never>
}
