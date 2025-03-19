//
//  DIContainer.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 2/27/25.
//

import Foundation
import ReactableKit
import DependencyInjectableKit

// MARK: - Factory Exmaple

protocol FactoryTestProtocol {
    func test() -> String
}

struct FactoryTest: FactoryTestProtocol, Factory {
    
    struct Payload { }
    let payload: Payload
    
    init(payload: Payload) {
        self.payload = payload
    }
    
    func test() -> String { "real \(payload)" }
}

struct FactoryTestMock: FactoryTestProtocol, Factory {
    let payload: FactoryTest.Payload
    
    init(payload: FactoryTest.Payload) {
        self.payload = payload
    }
    
    func test() -> String { "mock \(payload)" }
}

extension FactoryTest: DependencyInjectable {
    typealias DependencyType = AnyFactory<FactoryTestProtocol, Payload>
    
    static var real: DependencyType {
        DependencyType(factory: FactoryTest.Factory())
    }
    static var test: DependencyType {
        DependencyType(factory: FactoryTestMock.Factory())
    }
}

extension GlobalDependencyKey {
    var factoryTestFactory: FactoryTest.DependencyType {
        self[FactoryTest.self]
    }
}

// MARK: - Service Exmaple

protocol ServiceProtocol {
    func test() -> String
}

struct Service: ServiceProtocol {
    
    init() {
        print("Service init")
    }
    
    func test() -> String { "real" }
    
    struct Mock: ServiceProtocol {
        public init() {}
        public func test() -> String { "mock" }
    }
    
    struct TestMock: ServiceProtocol, Hashable {
        public init() {}
        public func test() -> String { "test" }
    }
}

extension Service: DependencyInjectable {
    static var real: ServiceProtocol { Service() }
    static var preview: ServiceProtocol { Service.Mock() }
    static var test: ServiceProtocol { Service.TestMock() }
}

extension GlobalDependencyKey {
    var service: ServiceProtocol {
        self[Service.self]
    }
}

// MARK: - Factory Class Exmaple

final class TestObject: Factory {
    struct Payload {
        var text = "text"
    }
    let payload: Payload
    
    deinit {
        print("TestObject deinit")
    }
    init(payload: Payload) {
        self.payload = payload
    }
    
    func print1() {
        print(self.payload.text)
    }
}

extension TestObject: DependencyInjectable {
    typealias DependencyType = TestObject.Factory
    
    static var real: TestObject.Factory { .init() }
}

extension GlobalDependencyKey {
    var testObjectFactory: TestObject.Factory {
        self[TestObject.self]
    }
}

// MARK: - Usage

struct DependencyExample {
    @Dependency(\.service) var service
    @Dependency(\.testObjectFactory) var testObjectFactory
    @Dependency(\.factoryTestFactory) var factoryTestFactory
    
    init() {
        self.service.test()
        let testObject = self.testObjectFactory.create(payload: .init(text: "111"))
        let factoryTest = self.factoryTestFactory.create(payload: .init())
    }
}
