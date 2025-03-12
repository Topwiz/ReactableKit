//
//  EmitTests.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/23/25.
//

import Testing
import Foundation
@testable import ReactableKit

struct EmitTests {
    // Test initialization with a wrapped value
    @Test
    func testInitialization() {
        let emit = Emit(wrappedValue: 10)
        #expect(emit.wrappedValue == 10)
        #expect(emit.count == 0)
    }

    // Test setting a new value
    @Test
    func testSettingValue() {
        var emit = Emit(wrappedValue: 10)
        emit.wrappedValue = 20
        #expect(emit.wrappedValue == 20)
    }

    // Test count increment on value change
    @Test
    func testCountIncrement() {
        var emit = Emit(wrappedValue: 10)
        #expect(emit.count == 0)
        emit.wrappedValue = 20
        #expect(emit.count == 1)
        emit.wrappedValue = 30
        #expect(emit.count == 2)
    }

    // Test equality
    @Test
    func testEquality() {
        let emit1 = Emit(wrappedValue: 10)
        let emit2 = Emit(wrappedValue: 10)
        #expect(emit1 == emit2)
    }
}
