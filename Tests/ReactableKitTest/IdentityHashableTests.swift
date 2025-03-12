//
//  IdentityHashableTest.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/24/25.
//

import Testing
import Foundation
@testable import ReactableKit

class TestObject: IdentityHashable { }
class TestObject1: IdentityHashable { }

struct IdentityHashableTest {
    @Test func testHash() {
        let test = TestObject()
        let test1 = TestObject()
        #expect(test.hashValue == test.hashValue, "Should be equal.")
        #expect(test === test, "Should be equal.")
        #expect(test == test, "Should be equal.")
        #expect(test.hashValue != test1.hashValue, "Should be different.")
    }
}
