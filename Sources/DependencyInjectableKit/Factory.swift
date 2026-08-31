//
//  Factory.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 3/6/25.
//

import Foundation

public protocol Factory {
    associatedtype Payload
    init(payload: Payload)
}

public extension Factory {
    typealias Factory = DefaultFactory<Self>
}

public struct DefaultFactory<T: Factory> {
    public init() { }
    public func create(payload: T.Payload) -> T {
        return T(payload: payload)
    }
}

public struct AnyFactory<Output, Payload> {
    private let _create: (Payload) -> Output

    public init<F>(
        factory: DefaultFactory<F>,
        transform: @escaping (F) -> Output
    ) where F: Factory, F.Payload == Payload {
        self._create = { payload in
            let value = factory.create(payload: payload)
            return transform(value)
        }
    }

    public func create(payload: Payload) -> Output {
        self._create(payload)
    }
}

public extension AnyFactory {
    init<F>(factory: DefaultFactory<F>) where F: Factory, F.Payload == Payload {
        self.init(factory: factory, transform: { value in
            guard let output = value as? Output else {
                fatalError("Factory output cannot be cast to Output")
            }
            return output
        })
    }
}
