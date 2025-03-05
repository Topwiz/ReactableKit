//
//  DependencyTest.swift
//  ExmapleAppTests
//
//  Created by Jeehoon Son on 3/6/25.
//

import Testing
import ReactableKit

struct DependencyTest {
    
    @Test
    func testDependency() {
        @Dependency(\.service) var service
        #expect(service.test() == "test")
        
        @Dependency(\.testObjectFactory) var testObjectFactory
        let test1 = testObjectFactory.create(payload: .init())
        let test2 = testObjectFactory.create(payload: .init())
        #expect(test1 !== test2)
    }

}

