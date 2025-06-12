//
//  SharedTests.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 3/13/25.
//

import Foundation
import Combine
import SwiftUI
import Testing
@testable import ReactableKit

struct SharedTests {

    // Test case to check the initial value of the shared property using memory storage
    @Test
    func testMemoryInitialization() {
        @Shared(.memory, key: "memoryKey1")
        var memoryValue: Int = 0
        #expect(memoryValue == 0)
    }

    // Test case to check if the shared property value can be updated using memory storage
    @Test
    func testMemoryUpdateValue() {
        @Shared(.memory, key: "memoryKey2")
        var memoryValue: Int = 0
        memoryValue = 10
        #expect(memoryValue == 10)
    }

    // Test case to check if the shared property value is published correctly using memory storage
    @Test
    func testMemoryPublisher() async {
        @Shared(.memory, key: "memoryKey3")
        var memoryValue: Int = 0
        var receivedValue: Int?
        let cancellable = $memoryValue.publisher.sink { value in
            receivedValue = value
        }

        memoryValue = 20
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(receivedValue == 20)
        cancellable.cancel()
    }

    // Test case to check the initial value of the shared property using UserDefaults
    @Test
    func testUserDefaultsInitialization() {
        @Shared(.userDefaults(), key: "userDefaultsKey1")
        var userDefaultsValue: Int = 0
        #expect(userDefaultsValue == 0)
    }

    // Test case to check if the shared property value can be updated using UserDefaults
    @Test
    func testUserDefaultsUpdateValue() {
        @Shared(.userDefaults(), key: "userDefaultsKey2")
        var userDefaultsValue: Int = 0
        userDefaultsValue = 10
        #expect(userDefaultsValue == 10)
    }

    // Test case to check if the shared property value is published correctly using UserDefaults
    @Test
    func testUserDefaultsPublisher() async {
        @Shared(.userDefaults(), key: "userDefaultsKey3")
        var userDefaultsValue: Int = 0
        var receivedValue: Int?
        let cancellable = $userDefaultsValue.publisher.sink { value in
            receivedValue = value
        }

        userDefaultsValue = 20
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(receivedValue == 20)
        cancellable.cancel()
    }

    // Test case to check the initial value of the shared property using file storage
    @Test
    func testFileInitialization() {
        @Shared(.file(), key: "fileKey1")
        var fileValue: Int = 0
        #expect(fileValue == 0)
    }

    // Test case to check if the shared property value can be updated using file storage
    @Test
    func testFileUpdateValue() {
        @Shared(.file(), key: "fileKey2")
        var fileValue: Int = 0
        fileValue = 10
        #expect(fileValue == 10)
    }

    // Test case to check if the shared property value is published correctly using file storage
    @Test
    func testFilePublisher() async {
        @Shared(.file(), key: "fileKey3")
        var fileValue: Int = 0
        var receivedValue: Int?
        let cancellable = $fileValue.publisher.sink { value in
            receivedValue = value
        }

        fileValue = 20
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(receivedValue == 20)
        cancellable.cancel()
    }
}
