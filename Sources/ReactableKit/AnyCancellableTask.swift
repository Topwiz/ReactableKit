//
//  AnyCancellableTask.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 7/1/25.
//

import Foundation

public protocol AnyCancellableTask {
    func cancel()
}

extension Task: AnyCancellableTask {}

public final class TaskCancellableBag {
    private var tasks: [any AnyCancellableTask] = []
    
    public init() {}

    public func add(task: any AnyCancellableTask) {
        self.tasks.append(task)
    }

    public func cancel() {
        self.tasks.forEach { $0.cancel() }
        self.tasks.removeAll()
    }
    
    deinit {
        self.cancel()
    }
}


extension Task {
    @discardableResult
    public func store(in bag: TaskCancellableBag) -> Task {
        bag.add(task: self)
        return self
    }
}
