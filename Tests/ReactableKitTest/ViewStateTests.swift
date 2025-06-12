//
//  ViewStateTests.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 3/13/25.
//

import Foundation
import Testing
@testable import ReactableKit

struct ViewStateTests {

    // Test initialization with a wrapped value
    @Test
    func testInitialization() {
        let viewState = ViewState(wrappedValue: 10)
        #expect(viewState.wrappedValue == 10)
    }

    // Test setting a new value
    @Test
    func testSettingValue() {
        let viewState = ViewState(wrappedValue: 10)
        viewState.wrappedValue = 20
        #expect(viewState.wrappedValue == 20)
    }

    // Test equality
    @Test
    func testEquality() {
        let viewState1 = ViewState(wrappedValue: 10)
        let viewState2 = ViewState(wrappedValue: 10)
        #expect(viewState1 == viewState2)
    }

    // Test onChange handler
    @Test
    func testOnChangeHandler() async{
        let viewState = ViewState(wrappedValue: 10)
        var didChange = false
        viewState.setOnChange {
            didChange = !didChange
        }
        
        viewState.wrappedValue = 20
        try? await Task.sleep(nanoseconds: 100_000)
        #expect(didChange)
        viewState.wrappedValue = 20
        try? await Task.sleep(nanoseconds: 100_000)
        #expect(didChange)
        viewState.wrappedValue = 10
        try? await Task.sleep(nanoseconds: 100_000)
        #expect(didChange == false)
    }

    // Test projected value
    @Test
    func testProjectedValue() {
        let viewState = ViewState(wrappedValue: 10)
        let binding = viewState.projectedValue
        binding.wrappedValue = 20
        #expect(viewState.wrappedValue == 20)
    }

    // Test ignore equality
    @Test
    func testIgnoreEquality() async {
        let viewState = ViewState(wrappedValue: 10, ignoreEquality: true)
        var didChange = false
        viewState.setOnChange {
            didChange = !didChange
        }
        viewState.wrappedValue = 10
        try? await Task.sleep(nanoseconds: 100_000)
        #expect(didChange)
        viewState.wrappedValue = 10
        try? await Task.sleep(nanoseconds: 100_000)
        #expect(didChange == false)
    }
}
