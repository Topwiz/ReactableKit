//
//  Publish.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import Combine

/// Defines an error type for asynchronous operations.
enum AsyncError: Error {
    case finishedWithoutValue
}

// MARK: - Combine Publisher Extensions

public extension Publisher where Output == Sendable {
    
    /// Waits for the first emitted value asynchronously using `async`.
    /// - Returns: The first emitted value of the publisher.
    /// - Throws: `AsyncError.finishedWithoutValue` if no value is received.
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var finishedWithoutValue = true
            
            cancellable = self.first()
                .sink(
                    receiveCompletion: { result in
                        switch result {
                        case .finished:
                            if finishedWithoutValue {
                                continuation.resume(throwing: AsyncError.finishedWithoutValue)
                            }
                        case let .failure(error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        finishedWithoutValue = false
                        continuation.resume(returning: value)
                    }
                )
        }
    }
}

// MARK: - Combine Utility Functions

public extension Publisher where Failure == Never {
    
    /// Creates a timer that emits values at a specified interval.
    /// - Parameters:
    ///   - interval: The time interval between emissions.
    ///   - scheduler: The run loop on which the timer runs (default: `.main`).
    /// - Returns: A publisher that emits the current date at the specified interval.
    static func timer(interval: TimeInterval, scheduler: RunLoop = .main) -> AnyPublisher<Date, Never> {
        Timer.publish(every: interval, on: scheduler, in: .default)
            .autoconnect()
            .eraseToAnyPublisher()
    }
    
    /// Creates an empty publisher that completes immediately.
    static func empty() -> AnyPublisher<Output, Never> {
        Empty<Output, Never>().eraseToAnyPublisher()
    }
    
    /// Creates a publisher that emits a single value immediately.
    /// - Parameter value: The value to emit.
    /// - Returns: A publisher emitting the given value.
    static func just(_ value: Output) -> AnyPublisher<Output, Never> {
        Just(value).eraseToAnyPublisher()
    }
}

// MARK: - Combine Transformation Operators

public extension Publisher {
    
    /// Merges multiple publishers into a single publisher.
    /// - Parameter publishers: The array of publishers to merge.
    /// - Returns: A merged publisher emitting values from all input publishers.
    static func merge(_ publishers: [AnyPublisher<Output, Failure>]) -> AnyPublisher<Output, Failure> {
        Publishers.MergeMany(publishers).eraseToAnyPublisher()
    }
    
    /// Concatenates multiple publishers sequentially.
    /// - Parameter publishers: The array of publishers to concatenate.
    /// - Returns: A concatenated publisher executing publishers in sequence.
    static func concat(_ publishers: [AnyPublisher<Output, Failure>]) -> AnyPublisher<Output, Failure> {
        guard let first = publishers.first else { return Empty<Output, Failure>().eraseToAnyPublisher() }
        
        return publishers.dropFirst().reduce(first) { acc, next in
            acc.append(next).eraseToAnyPublisher()
        }
    }
}

// MARK: - Timing & Filtering Operators

public extension Publisher {
    
    /// Delays emission of values by a specified time interval.
    /// - Parameters:
    ///   - interval: The time delay before values are emitted.
    ///   - scheduler: The scheduler on which the delay is applied.
    func delay(for interval: TimeInterval, scheduler: DispatchQueue) -> AnyPublisher<Output, Failure> {
        self.delay(for: .seconds(interval), scheduler: scheduler)
            .eraseToAnyPublisher()
    }
    
    /// Throttles values to emit at a limited rate.
    /// - Parameters:
    ///   - interval: The time window for throttling.
    ///   - scheduler: The scheduler on which the throttle is applied.
    ///   - latest: Whether to emit the latest value (default: `true`).
    func throttle(for interval: TimeInterval, scheduler: DispatchQueue, latest: Bool = true) -> AnyPublisher<Output, Failure> {
        self.throttle(for: .seconds(interval), scheduler: scheduler, latest: latest)
            .eraseToAnyPublisher()
    }
    
    /// Removes consecutive duplicate values.
    func distinctUntilChanged() -> AnyPublisher<Output, Failure> where Output: Equatable {
        self.removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    func withIndex() -> AnyPublisher<(index: Int, value: Output), Failure> {
        self.scan((index: -1, value: nil as Output?)) { (acc, value) in
            (index: acc.index + 1, value: value)
        }
        .compactMap { (index, value) -> (index: Int, value: Output)? in
            guard let value = value else { return nil }
            return (index, value)
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Data Transformation Operators

public extension Publisher {
    
    /// Emits values until another publisher emits a value.
    /// - Parameter trigger: A publisher that stops the emission of values.
    /// - Returns: A publisher that stops when the trigger emits a value.
    func takeUntil<T>(_ trigger: AnyPublisher<T, Failure>) -> AnyPublisher<Output, Failure> {
        self.prefix(untilOutputFrom: trigger)
            .eraseToAnyPublisher()
    }
}

// MARK: - Receiving and Debugging

public extension Publisher {
    
    /// Adds logging for debugging purposes.
    /// - Parameter prefix: The prefix for log messages.
    /// - Returns: A publisher with logging applied.
    func debug(_ prefix: String = "Publisher") -> AnyPublisher<Output, Failure> {
        self.handleEvents(
            receiveSubscription: { _ in print("\(prefix) - Subscription started") },
            receiveOutput: { output in print("\(prefix) - Received value: \(output)") },
            receiveCompletion: { completion in print("\(prefix) - Completion: \(completion)") },
            receiveCancel: { print("\(prefix) - Cancelled") },
            receiveRequest: { demand in print("\(prefix) - Demand: \(demand)") }
        )
        .eraseToAnyPublisher()
    }
}

extension PassthroughSubject: @unchecked @retroactive Sendable where Output: Sendable {}

final class TaskHolder {
    var task: Task<Void, Never>?
}

/// A type that can send values back into the publisher when used from `run` operations.
/// This type implements `callAsFunction` so that you invoke it as a function.
public struct Send<Output>: Sendable {
    let send: @Sendable (Output) -> Void
    
    public init(send: @escaping @Sendable (Output) -> Void) {
        self.send = send
    }
    
    /// Sends a value back into the publisher from an async operation.
    /// - Parameter output: The value to send.
    public func callAsFunction(_ output: Output) {
        guard !Task.isCancelled else { return }
        self.send(output)
    }
}

public extension AnyPublisher where Output: Sendable, Failure == Never {
    
    /// Creates a publisher that wraps an asynchronous unit of work that can emit values any number of times.
    ///
    /// The closure provided to `run` is allowed to throw, but any non-cancellation errors thrown
    /// will be handled by the optional `catch` parameter.
    ///
    /// - Parameters:
    ///   - priority: Priority of the underlying task. If `nil`, the priority will come from `Task.currentPriority`.
    ///   - operation: The async operation to execute.
    ///   - handler: An error handler, invoked if the operation throws an error other than `CancellationError`.
    /// - Returns: A publisher wrapping the given asynchronous work.
    static func run(
        priority: TaskPriority? = nil,
        operation: @Sendable @escaping (_ send: Send<Output>) async throws -> Void,
        catch handler: (@Sendable (_ error: any Error, _ send: Send<Output>) async -> Void)? = nil
    ) -> AnyPublisher<Output, Never> {
        Deferred {
            let subject = PassthroughSubject<Output, Never>()
            let taskHolder = TaskHolder()
            
            return subject
                .receive(on: DispatchQueue.main)
                .handleEvents(
                    receiveSubscription: { _ in
                        taskHolder.task = Task(priority: priority) { @MainActor in
                            let send = Send<Output> { output in
                                guard !Task.isCancelled else { return }
                                subject.send(output)
                            }
                            
                            do {
                                try await operation(send)
                                
                                guard !Task.isCancelled else { return }
                                subject.send(completion: .finished)
                            } catch is CancellationError {
                                return
                            } catch {
                                guard let handler else {
                                    #if DEBUG
                                    Swift.print("ReactableKit: Unhandled error in run operation: \(error)")
                                    #endif
                                    return
                                }
                                await handler(error, send)
                                
                                guard !Task.isCancelled else { return }
                                subject.send(completion: .finished)
                            }
                        }
                    },
                    receiveCancel: {
                        taskHolder.task?.cancel()
                    }
                )
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    /// Creates a publisher that emits a single value from an async operation
    /// - Parameter operation: An async operation that returns a single value
    /// - Returns: A publisher that emits the result value once and then completes
    static func async(
        _ operation: @Sendable @escaping () async -> Output
    ) -> AnyPublisher<Output, Never> {
        Deferred {
            let subject = PassthroughSubject<Output, Never>()
            let taskHolder = TaskHolder()
            
            return subject
                .handleEvents(
                    receiveSubscription: { _ in
                        taskHolder.task = Task {
                            guard !Task.isCancelled else { return }
                            let result = await operation()
                            Task { @MainActor in
                                guard !Task.isCancelled else { return }
                                subject.send(result)
                                subject.send(completion: .finished)
                            }
                        }
                    },
                    receiveCancel: {
                        taskHolder.task?.cancel()
                    }
                )
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    /// Creates a publisher that emits a single value from a MainActor async operation
    /// - Parameter operation: A MainActor async operation that returns a single value
    /// - Returns: A publisher that emits the result value once and then completes
    static func mainAsync(
        _ operation: @MainActor @escaping () async -> Output
    ) -> AnyPublisher<Output, Never> {
        Deferred {
            let subject = PassthroughSubject<Output, Never>()
            let taskHolder = TaskHolder()
            
            return subject
                .handleEvents(
                    receiveSubscription: { _ in
                        taskHolder.task = Task { @MainActor in
                            guard !Task.isCancelled else { return }
                            let result = await operation()
                            guard !Task.isCancelled else { return }
                            subject.send(result)
                            subject.send(completion: .finished)
                        }
                    },
                    receiveCancel: {
                        taskHolder.task?.cancel()
                    }
                )
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    
    /// Maps each value from the publisher using a MainActor async transformation
    /// - Parameter transform: A MainActor async transformation function
    /// - Returns: A publisher that emits transformed values
    func mainAsyncMap<T: Sendable>(
        _ transform: @MainActor @escaping (Output) async -> T
    ) -> AnyPublisher<T, Never> {
        self.flatMap { value in
            AnyPublisher<T, Never>.mainAsync {
                return await transform(value)
            }
        }
        .eraseToAnyPublisher()
    }
}

public extension Publisher where Failure == Never {
    func bind(to action: @escaping (Output) -> Void) -> AnyCancellable {
        self.sink(receiveValue: action)
    }
}

public extension Publisher where Failure: Error {
    func bind(to method: @escaping (Output) -> Void) -> AnyCancellable {
        self.catch { _ in Empty<Output, Never>() }
            .sink(receiveValue: method)
    }
}
