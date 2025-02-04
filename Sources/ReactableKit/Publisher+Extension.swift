//
//  Publish.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation
import Combine

enum AsyncError: Error {
    case finishedWithoutValue
}

import Combine
import Foundation

// MARK: - Combine Publisher Extensions

public extension Publisher where Output == Sendable {
    
    /// `async`를 사용하여 첫 번째 값이 도착할 때까지 기다리는 비동기 함수
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
    
    /// 일정 간격으로 값을 발행하는 타이머 생성
    static func timer(interval: TimeInterval, scheduler: RunLoop = .main) -> AnyPublisher<Date, Never> {
        Timer.publish(every: interval, on: scheduler, in: .default)
            .autoconnect()
            .eraseToAnyPublisher()
    }
    
    /// 즉시 완료되는 빈 Publisher 생성
    static func empty() -> AnyPublisher<Output, Never> {
        Empty<Output, Never>().eraseToAnyPublisher()
    }
    
    /// 주어진 값을 즉시 방출하는 Publisher 생성
    static func just(_ value: Output) -> AnyPublisher<Output, Never> {
        Just(value).eraseToAnyPublisher()
    }
}

// MARK: - Combine Transformation Operators

public extension Publisher {
    
    /// 여러 개의 Publisher를 병합
    static func merge(_ publishers: [AnyPublisher<Output, Failure>]) -> AnyPublisher<Output, Failure> {
        Publishers.MergeMany(publishers).eraseToAnyPublisher()
    }
    
    /// 여러 개의 Publisher를 순차적으로 실행
    static func concat(_ publishers: [AnyPublisher<Output, Failure>]) -> AnyPublisher<Output, Failure> {
        guard let first = publishers.first else { return Empty<Output, Failure>().eraseToAnyPublisher() }
        
        return publishers.dropFirst().reduce(first) { acc, next in
            acc.append(next).eraseToAnyPublisher()
        }
    }
}

// MARK: - Timing & Filtering Operators

public extension Publisher {
    
    /// 지정된 시간 후 값 발행
    func delay(for interval: TimeInterval, scheduler: DispatchQueue) -> AnyPublisher<Output, Failure> {
        self.delay(for: .seconds(interval), scheduler: scheduler)
            .eraseToAnyPublisher()
    }
    
    /// 지정된 시간 간격 동안 값 스로틀링
    func throttle(for interval: TimeInterval, scheduler: DispatchQueue, latest: Bool = true) -> AnyPublisher<Output, Failure> {
        self.throttle(for: .seconds(interval), scheduler: scheduler, latest: latest)
            .eraseToAnyPublisher()
    }
    
    /// 중복된 값 제거
    func distinctUntilChanged() -> AnyPublisher<Output, Failure> where Output: Equatable {
        self.removeDuplicates()
            .eraseToAnyPublisher()
    }
}

// MARK: - Data Transformation Operators

public extension Publisher {

    /// 다른 `Publisher`가 값을 방출할 때까지 값을 방출
    func takeUntil<T>(_ trigger: AnyPublisher<T, Failure>) -> AnyPublisher<Output, Failure> {
        self.prefix(untilOutputFrom: trigger)
            .eraseToAnyPublisher()
    }
}

// MARK: - Receiving and Debugging

public extension Publisher {
    
    /// `sink`를 통해 값과 오류를 옵셔빙 (옵셔널 지원)
    func sink(
        receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil,
        receiveValue: ((Output) -> Void)? = nil
    ) -> AnyCancellable {
        return self.sink(
            receiveCompletion: { completion in
                receiveCompletion?(completion)
            },
            receiveValue: { value in
                receiveValue?(value)
            }
        )
    }
    
    /// 디버깅을 위한 로깅 기능 추가
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
