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
    nonisolated(unsafe) static let asyncAction = WeakKeyDictionary<AnyObject, Any>()
}

public protocol Reactable: AnyObject, IdentityHashable {
    associatedtype Action: Sendable
    associatedtype Mutation: Sendable
    associatedtype State: Sendable
    typealias AsyncMutation = Send<Mutation>
    
    var initialState: State { get }
    var state: AnyPublisher<State, Never> { get }
    var currentState: State { get }
    var cancellables: Set<AnyCancellable> { get set }
    var resultSubject: PassthroughSubject<ObservableEventResult<Self>, Never> { get set }
    
    func initialize()
    func action(_ action: Action)
    func mutate(action: Action) -> AnyPublisher<Mutation, Never>
    func reduce(state: inout State, mutation: Mutation)
    func transformAction() -> AnyPublisher<Action, Never>

    #if DEBUG
    /// Instrumentation configuration for this Reactable's cycle: `os_signpost` intervals for
    /// queue latency, mutate, effect, and reduce, plus a warning whenever a stage exceeds its
    /// threshold.
    ///
    /// Returns `nil` by default, which means this Reactable is not measured. Override it to opt
    /// in — global switches (`ReactableInstrument.enabledByDefault`, `filter`, or the
    /// `REACTABLE_INSTRUMENT` environment variable) can still enable it without an override.
    /// Removed entirely from release builds.
    var instrumentation: ReactableInstrument.Options? { get }
    #endif
}

public extension Reactable {
    
    private var stream: Stream<IdentityAction, State> {
        WeakCache.stream.forceCastedValue(forKey: self, default: self.createStream())
    }
    
    var state: AnyPublisher<State, Never> {
        self.stream.state.publisher()
    }
    
    var currentState: State {
        WeakCache.currentState.forceCastedValue(forKey: self, default: self.initialState)
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
    
    #if DEBUG
    var instrumentation: ReactableInstrument.Options? { nil }
    #endif
    
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
    
    internal var asyncAction: PassthroughSubject<IdentityAction, Never> {
        get { WeakCache.asyncAction.forceCastedValue(forKey: self, default: .init()) }
        set { WeakCache.asyncAction.setValue(newValue, forKey: self) }
    }
}

public extension Reactable {
    
    internal typealias IdentityAction = Identity<Self, Self.Action>
    
    func action(_ action: Action) {
        let stream = self.stream
        // Stamped here, before the hop, so the measured queue latency includes the time this
        // action spends waiting behind whatever else is already on the main queue.
        let identity = IdentityAction.stamped(action)
        DispatchQueue.main.async {
            stream.action.send(identity)
        }
    }
    
    internal func asyncAction(_ action: IdentityAction) {
        let asyncAction = self.asyncAction
        DispatchQueue.main.async {
            asyncAction.send(action)
        }
    }
    
    @MainActor
    @discardableResult
    internal func mainActorAction(_ action: Action) async -> State {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self else { return }
            let identity = IdentityAction.stamped(action, continuation: continuation)
            self.asyncAction(identity)
        }
    }
    
    @discardableResult
    func asyncAction(_ action: Action) async -> State {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self else { return }
            let identity = IdentityAction.stamped(action, continuation: continuation)
            self.asyncAction(identity)
        }
    }
    
    private func createStream() -> Stream<IdentityAction, State> {
        let actionSubject = PassthroughSubject<IdentityAction, Never>()
        let stateSubject = ReplaySubject<State, Never>(bufferSize: 1)

        let stream = Stream(action: actionSubject, state: stateSubject)
        WeakCache.stream.setValue(stream, forKey: self)

        #if DEBUG
        // Resolved once per stream rather than once per action: building this string on every
        // cycle would be exactly the kind of hidden cost the instrument exists to catch.
        let instrumentName = String(describing: type(of: self))
        #endif

        let transformedActionStream = self.transformAction()
            .eraseToAnyPublisher()

        let mergedActionStream = Publishers.Merge3(
            actionSubject.eraseToAnyPublisher(),
            transformedActionStream.map { IdentityAction.stamped($0) }.eraseToAnyPublisher(),
            self.asyncAction.eraseToAnyPublisher()
        )
            .receive(on: DispatchQueue.main)

        let mutationStream = mergedActionStream
            .flatMap { [weak self] identity -> AnyPublisher<(IdentityAction, Mutation), Never> in
                guard let self = self else { return .empty() }

                let mutationPublisher: AnyPublisher<Mutation, Never>
                #if DEBUG
                var identity = identity
                // `isStub` is read per action rather than once per stream: a Reactable can be
                // wrapped in a `Stub` after its stream already exists, and `Stub` drives
                // `mutate`/`reduce` directly *and* through the stream, so measuring it would count
                // every sample twice. Checked after `resolveOptions` so a Reactable nobody asked to
                // measure never pays for the lookup.
                if let options = ReactableInstrument.resolveOptions(
                       name: instrumentName,
                       instrumentation: self.instrumentation
                   ),
                   !self.isStub {
                    // One lazily-derived case name shared by all three measurements below, so the
                    // reflection runs at most once per action — and not at all if nothing needs it.
                    // Carried on the identity so the reduce stage reuses this resolution instead
                    // of taking the process-wide instrument lock again for every mutation.
                    identity.instrumentOptions = options
                    let actionName = ReactableInstrument.LazyName.caseName(of: identity.action)
                    if let enqueuedAt = identity.enqueuedAt {
                        ReactableInstrument.recordQueueLatency(
                            options: options,
                            reactable: instrumentName,
                            action: actionName,
                            enqueuedAt: enqueuedAt
                        )
                    }
                    mutationPublisher = ReactableInstrument.measureEffect(
                        ReactableInstrument.measureMutate(
                            options: options,
                            reactable: instrumentName,
                            action: actionName
                        ) {
                            self.mutate(action: identity.action)
                        },
                        options: options,
                        reactable: instrumentName,
                        action: actionName
                    )
                } else {
                    mutationPublisher = self.mutate(action: identity.action)
                }
                #else
                mutationPublisher = self.mutate(action: identity.action)
                #endif

                return mutationPublisher
                    .map { (identity, $0) }
                    .handleEvents(receiveCompletion: { [weak self] completion in
                        guard let self else { return }
                        if case .finished = completion {
                            self.sendGlobalActionIfNeeded(identity.action, state: self.currentState)
                            if let completion = identity.continuation {
                                completion.resume(returning: self.currentState)
                            }
                        }
                    })
                    .eraseToAnyPublisher()
            }

        let stateStream = mutationStream
            .scan((nil as IdentityAction?, self.initialState)) { [weak self] acc, tuple in
                guard let self else { return acc }
                let (_, prevState) = acc
                let (action, mutation) = tuple
                var newState = prevState
                #if DEBUG
                if let options = action.instrumentOptions {
                    ReactableInstrument.measureReduce(
                        options: options,
                        reactable: instrumentName,
                        mutation: .caseName(of: mutation)
                    ) {
                        self.reduce(state: &newState, mutation: mutation)
                    }
                } else {
                    self.reduce(state: &newState, mutation: mutation)
                }
                #else
                self.reduce(state: &newState, mutation: mutation)
                #endif
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

        return stream
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

struct Identity<R: Reactable, A: Sendable>: Sendable {
    var action: A
    var continuation: CheckedContinuation<R.State, Never>?
    #if DEBUG
    /// Monotonic timestamp taken when the action was handed to the main queue, used to measure
    /// how long it waited before `mutate` ran. Release builds do not carry this.
    var enqueuedAt: UInt64?
    /// Instrument options resolved once in the mutate stage and reused by reduce, so the
    /// process-wide instrument lock is taken once per action rather than once per mutation.
    var instrumentOptions: ReactableInstrument.Options?
    #endif

    /// Builds an identity, stamping the enqueue time in DEBUG builds.
    static func stamped(_ action: A) -> Identity<R, A> {
        #if DEBUG
        Identity(action: action, enqueuedAt: ReactableInstrument.timestamp())
        #else
        Identity(action: action)
        #endif
    }

    static func stamped(
        _ action: A,
        continuation: CheckedContinuation<R.State, Never>
    ) -> Identity<R, A> {
        #if DEBUG
        Identity(action: action, continuation: continuation, enqueuedAt: ReactableInstrument.timestamp())
        #else
        Identity(action: action, continuation: continuation)
        #endif
    }
}
