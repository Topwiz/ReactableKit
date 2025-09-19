//
//  Reactable.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/24/25.
//

import SwiftUI
import Combine

/// AsyncStream-based Stream structure
public struct ReactableStream<Action: Sendable, State: Sendable> {
    let action: AsyncChannel<Action>
    let state: AsyncChannel<State>
}

/// Action with continuation for async response
struct IdentityAction<Action: Sendable, State: Sendable> {
    let action: Action
    let continuation: CheckedContinuation<State, Never>?
    
    init(action: Action, continuation: CheckedContinuation<State, Never>? = nil) {
        self.action = action
        self.continuation = continuation
    }
}

/// Type for sending mutations
public typealias MutationSender<Mutation> = @Sendable @MainActor (Mutation) async -> Void

/// Pure Async/Await based Reactable protocol
@MainActor
public protocol Reactable: AnyObject, IdentityHashable {
    associatedtype Action: Sendable
    associatedtype Mutation: Sendable
    associatedtype State: Sendable
    
    var initialState: State { get }
    var state: State { get }
    var currentState: State? { get }
    var statePublisher: AnyPublisher<State, Never> { get }
    
    func initialize()
    func action(_ action: Action) async -> State
    func action(_ action: Action)
    func mutate(action: Action, state: State, send: @escaping MutationSender<Mutation>) async
    func reduce(state: inout State, mutation: Mutation)
    func transformAction() -> AsyncStream<Action>?
}

// MARK: - Private Cache

enum ReactableCache {
    nonisolated(unsafe) static let stream = WeakKeyDictionary<AnyObject, Any>()
    nonisolated(unsafe) static let currentState = WeakKeyDictionary<AnyObject, Any>()
    nonisolated(unsafe) static let taskBag = WeakKeyDictionary<AnyObject, TaskCancellableBag>()
    nonisolated(unsafe) static let stateObservers = WeakKeyDictionary<AnyObject, Any>()
    nonisolated(unsafe) static let statePublisher = WeakKeyDictionary<AnyObject, Any>()
    nonisolated(unsafe) static let isStub = WeakKeyDictionary<AnyObject, Bool>()
    nonisolated(unsafe) static let identityActionChannel = WeakKeyDictionary<AnyObject, Any>()
}

// MARK: - Default Implementation
@MainActor
public extension Reactable {
    
    // MARK: Properties
    
    private var stream: ReactableStream<Action, State> {
        ReactableCache.stream.forceCastedValue(
            forKey: self,
            default: self.createStream()
        )
    }
    
    private var identityActionChannel: AsyncChannel<IdentityAction<Action, State>> {
        ReactableCache.identityActionChannel.forceCastedValue(
            forKey: self,
            default: AsyncChannel<IdentityAction<Action, State>>()
        )
    }
    
    private var taskBag: TaskCancellableBag {
        ReactableCache.taskBag.forceCastedValue(
            forKey: self,
            default: TaskCancellableBag()
        )
    }
    
    internal(set) var state: State {
        get {
            ReactableCache.currentState.forceCastedValue(forKey: self, default: self.initialState)
        }
        set {
            ReactableCache.currentState.setValue(newValue, forKey: self)
            self.stateSubject.send(newValue)
            Task {
                await self.stream.state.send(newValue)
            }
        }
    }
    
    var statePublisher: AnyPublisher<State, Never> {
        self.stateSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    internal var stateSubject: CurrentValueSubject<State, Never> {
        ReactableCache.statePublisher.forceCastedValue(
            forKey: self,
            default: CurrentValueSubject(self.initialState)
        )
    }
    
    /// Synchronous thread-safe way to get current state
    /// Returns the cached state value which is thread-safe to read
    nonisolated var currentState: State? {
        ReactableCache.currentState.value(forKey: self) as? State
    }
    
    /// Test stub support
    var isStub: Bool {
        get { ReactableCache.isStub.forceCastedValue(forKey: self, default: false) }
        set { ReactableCache.isStub.setValue(newValue, forKey: self) }
    }
    
    // MARK: Public Methods
    
    func initialize() {
        self.taskBag.cancel()
        _ = self.stream
        
        self.state = self.initialState
        
        Task {
            await self.startStreamProcessing()
        }
    }
    
    @discardableResult
    func action(_ action: Action) async -> State {
        await withCheckedContinuation { continuation in
            let identity = IdentityAction<Action, State>(action: action, continuation: continuation)
            Task {
                await self.identityActionChannel.send(identity)
            }
        }
    }
    
    @discardableResult
    func action(_ action: Action) {
        let identity = IdentityAction<Action, State>(action: action, continuation: nil)
        Task {
            await self.identityActionChannel.send(identity)
        }
    }
    
    // MARK: Default Implementations
    
    func mutate(action: Action, state: State, send: @escaping MutationSender<Mutation>) async { }
    
    func reduce(state: inout State, mutation: Mutation) { }
    
    func transformAction() -> AsyncStream<Action>? { nil }
    
    // MARK: Private Methods
    
    private func createStream() -> ReactableStream<Action, State> {
        let actionChannel = AsyncChannel<Action>()
        let stateChannel = AsyncChannel<State>()
        
        return ReactableStream(
            action: actionChannel,
            state: stateChannel
        )
    }
    
    private func startStreamProcessing() async {
        if let transformedActions = self.transformAction() {
            Task {
                for await action in transformedActions {
                    guard !Task.isCancelled else { break }
                    let identity = IdentityAction<Action, State>(action: action)
                    await self.identityActionChannel.send(identity)
                }
            }.store(in: self.taskBag)
        }
        
        Task {
            for await action in self.stream.action {
                guard !Task.isCancelled else { break }
                let identity = IdentityAction<Action, State>(action: action)
                await self.identityActionChannel.send(identity)
            }
        }.store(in: self.taskBag)
        
        for await identity in identityActionChannel {
            guard !Task.isCancelled else { break }
            
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                
                await self.mutate(action: identity.action, state: self.state) { mutation in
                    var newState = self.state
                    self.reduce(state: &newState, mutation: mutation)
                    self.state = newState
                }
                
                self.sendObservableEvent(identity.action, state: self.state)
                identity.continuation?.resume(returning: self.state)
            }
        }
    }
}
