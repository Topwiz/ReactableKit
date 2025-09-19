//
//  AsyncChannel.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/24/25.
//

import Foundation

/// Channel for asynchronously passing actions
public final class AsyncChannel<Element: Sendable>: AsyncSequence, Sendable {
    public typealias AsyncIterator = AsyncStream<Element>.AsyncIterator
    public typealias Element = Element
    
    private let stream: AsyncStream<Element>
    private let continuation: AsyncStream<Element>.Continuation
    
    public init(bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded) {
        var continuation: AsyncStream<Element>.Continuation!
        self.stream = AsyncStream(bufferingPolicy: bufferingPolicy) { cont in
            continuation = cont
        }
        self.continuation = continuation
    }
    
    /// Element를 채널로 전송
    public func send(_ element: Element) async {
        self.continuation.yield(element)
    }
    
    /// 채널 종료
    public func finish() {
        self.continuation.finish()
    }
    
    /// AsyncSequence 프로토콜 준수
    public func makeAsyncIterator() -> AsyncStream<Element>.AsyncIterator {
        self.stream.makeAsyncIterator()
    }
    
    deinit {
        self.continuation.finish()
    }
}
