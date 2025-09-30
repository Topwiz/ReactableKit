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

    // MARK: - Ephemeral memory behavior

    // `.memory` should drop state when all references are released
    @Test
    func testMemoryEphemeralResetsAfterDeallocation() {
        let key = "managed_ref_memory_ephemeral_key"

        // First scope: set non-default
        do {
            @Shared(.memory, key: key)
            var value: Int = 0
            value = 42
            #expect(value == 42)
        }

        // New scope: reference recreated, should read default
        do {
            @Shared(.memory, key: key)
            var value: Int = 0
            #expect(value == 0)
        }
    }

    // MARK: - Persistence behavior

    // Persistent storage (UserDefaults) should keep the last value across new wrappers
    @Test
    func testPersistentUserDefaultsPersistsAcrossReinstantiation() {
        let key = "managed_ref_persistent_ud_key"

        do {
            @Shared(.userDefaults(), key: key)
            var value: Int = 0
            value = 77
            #expect(value == 77)
        }

        do {
            @Shared(.userDefaults(), key: key)
            var value: Int = 0
            #expect(value == 77)
        }
    }

    // MARK: - Publisher retains and releases underlying reference

    // While there is an active subscription to publisher, `.memory` reference should be retained.
    // After the subscription is cancelled and no references remain, the value should reset to default.
    @Test
    func testMemoryPublisherRetainsWhileSubscribedAndReleasesAfterCancel() async {
        let key = "managed_ref_memory_pub_retain_release"
        var cancellable: AnyCancellable?

        // Create a value and subscribe to keep the reference alive
        do {
            @Shared(.memory, key: key)
            var value: Int = 0
            cancellable = $value.publisher.sink { _ in }
            value = 123
            #expect(value == 123)
        }

        // Even though the wrapper went out of scope, the subscription should keep the reference alive
        do {
            @Shared(.memory, key: key)
            var value: Int = 0
            // Allow any async propagation
            try? await Task.sleep(nanoseconds: 200_000_000)
            #expect(value == 123)
        }

        // Cancel subscription; with no references, the ephemeral memory should reset
        cancellable?.cancel()
        cancellable = nil
        try? await Task.sleep(nanoseconds: 200_000_000)

        do {
            @Shared(.memory, key: key)
            var value: Int = 0
            #expect(value == 0)
        }
    }

    // MARK: - Cross-instance publisher sharing tests

    // Test that multiple Shared instances with the same key share publisher updates
    @Test
    func testSameKeyInstancesSharePublisherUpdates() async {
        let key = "shared_publisher_key_1"
        var receivedValues1: [Int] = []
        var receivedValues2: [Int] = []
        var cancellables = Set<AnyCancellable>()
        
        // Create two Shared instances with the same key
        @Shared(.memory, key: key)
        var shared1: Int = 0
        
        @Shared(.memory, key: key)
        var shared2: Int = 0
        
        // Subscribe to both publishers
        $shared1.publisher
            .dropFirst() // Skip initial value
            .sink { value in
                receivedValues1.append(value)
            }
            .store(in: &cancellables)
        
        $shared2.publisher
            .dropFirst() // Skip initial value
            .sink { value in
                receivedValues2.append(value)
            }
            .store(in: &cancellables)
        
        // Update shared1 and check if shared2 receives it
        shared1 = 10
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Update shared2 and check if shared1 receives it
        shared2 = 20
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Both should have received both updates
        #expect(receivedValues1.contains(10))
        #expect(receivedValues1.contains(20))
        #expect(receivedValues2.contains(10))
        #expect(receivedValues2.contains(20))
        
        // Values should be in sync
        #expect(shared1 == 20)
        #expect(shared2 == 20)
        
        cancellables.removeAll()
    }
    
    // Test that different keys don't interfere with each other
    @Test
    func testDifferentKeysDoNotInterfereWithPublishers() async {
        var receivedValuesA: [Int] = []
        var receivedValuesB: [Int] = []
        var cancellables = Set<AnyCancellable>()
        
        @Shared(.memory, key: "key_a")
        var sharedA: Int = 0
        
        @Shared(.memory, key: "key_b")
        var sharedB: Int = 0
        
        // Subscribe to both publishers
        $sharedA.publisher
            .dropFirst()
            .sink { value in
                receivedValuesA.append(value)
            }
            .store(in: &cancellables)
        
        $sharedB.publisher
            .dropFirst()
            .sink { value in
                receivedValuesB.append(value)
            }
            .store(in: &cancellables)
        
        // Update sharedA
        sharedA = 100
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Update sharedB
        sharedB = 200
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Each should only receive its own updates
        #expect(receivedValuesA == [100])
        #expect(receivedValuesB == [200])
        
        cancellables.removeAll()
    }
    
    // Test cross-instance publisher sharing with UserDefaults storage
    @Test
    func testUserDefaultsCrossInstancePublisherSharing() async {
        let key = "ud_shared_publisher_key"
        var receivedValues1: [String] = []
        var receivedValues2: [String] = []
        var cancellables = Set<AnyCancellable>()
        
        // Clean up any existing value
        UserDefaults.standard.removeObject(forKey: key)
        
        @Shared(.userDefaults(), key: key)
        var shared1: String = "initial"
        
        @Shared(.userDefaults(), key: key)
        var shared2: String = "initial"
        
        // Subscribe to both publishers
        $shared1.publisher
            .dropFirst()
            .sink { value in
                receivedValues1.append(value)
            }
            .store(in: &cancellables)
        
        $shared2.publisher
            .dropFirst()
            .sink { value in
                receivedValues2.append(value)
            }
            .store(in: &cancellables)
        
        // Update through first instance
        shared1 = "updated_from_1"
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Update through second instance
        shared2 = "updated_from_2"
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Both should receive both updates
        #expect(receivedValues1.contains("updated_from_1"))
        #expect(receivedValues1.contains("updated_from_2"))
        #expect(receivedValues2.contains("updated_from_1"))
        #expect(receivedValues2.contains("updated_from_2"))
        
        // Values should be in sync
        #expect(shared1 == "updated_from_2")
        #expect(shared2 == "updated_from_2")
        
        cancellables.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    // Test that publisher subscription retains shared reference for memory storage
    @Test
    func testPublisherSubscriptionRetainsMemoryReference() async {
        let key = "memory_retain_key"
        var receivedValues: [Int] = []
        var cancellable: AnyCancellable?
        
        // Create and update value in a scope
        do {
            @Shared(.memory, key: key)
            var shared: Int = 0
            
            // Subscribe to publisher
            cancellable = $shared.publisher
                .dropFirst()
                .sink { value in
                    receivedValues.append(value)
                }
            
            shared = 42
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Reference should still be alive due to publisher subscription
        do {
            @Shared(.memory, key: key)
            var shared: Int = 0
            
            // Should still have the updated value
            #expect(shared == 42)
            
            // Update again to test publisher still works
            shared = 84
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Should have received both updates
        #expect(receivedValues.contains(42))
        #expect(receivedValues.contains(84))
        
        // Cancel subscription
        cancellable?.cancel()
        cancellable = nil
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Now memory should reset
        do {
            @Shared(.memory, key: key)
            var shared: Int = 0
            #expect(shared == 0) // Back to default
        }
    }
    
    // Test multiple subscribers to the same key
    @Test
    func testMultipleSubscribersToSameKey() async {
        let key = "multi_subscriber_key"
        var receivedValues1: [Int] = []
        var receivedValues2: [Int] = []
        var receivedValues3: [Int] = []
        var cancellables = Set<AnyCancellable>()
        
        @Shared(.memory, key: key)
        var shared: Int = 0
        
        // Create multiple subscribers
        $shared.publisher
            .dropFirst()
            .sink { value in
                receivedValues1.append(value)
            }
            .store(in: &cancellables)
        
        $shared.publisher
            .dropFirst()
            .sink { value in
                receivedValues2.append(value)
            }
            .store(in: &cancellables)
        
        $shared.publisher
            .dropFirst()
            .sink { value in
                receivedValues3.append(value)
            }
            .store(in: &cancellables)
        
        // Update value
        shared = 111
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        shared = 222
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // All subscribers should receive all updates
        #expect(receivedValues1 == [111, 222])
        #expect(receivedValues2 == [111, 222])
        #expect(receivedValues3 == [111, 222])
        
        cancellables.removeAll()
    }
}
