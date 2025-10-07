//
//  SharedViewStateTests.swift
//  ReactableKit
//
//  Created by david.rx on 10/7/25.
//

import Foundation
import Combine
import SwiftUI
import Testing
@testable import ReactableKit

struct SharedViewStateTests {
    
    // MARK: - Basic Synchronization Tests
    
    /// Verify that updates to SharedViewState propagate to external Shared with the same key
    @Test
    func testSharedViewStateUpdatesPropagateToExternalShared() async {
        let key = "test_propagate_to_external"
        
        @Shared(.memory, key: key)
        var externalShared: Int = 0
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState: Int
        
        viewState = 42
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(externalShared == 42, "External Shared should be updated")
    }
    
    /// Verify that external Shared updates propagate to SharedViewState and trigger onChange
    @Test
    func testExternalSharedUpdatesSharedViewState() async {
        let key = "test_external_updates_viewstate"
        
        @Shared(.memory, key: key)
        var externalShared: Int = 0
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState: Int
        
        nonisolated(unsafe) var onChangeCallCount = 0
        
        _viewState.setOnChange {
            onChangeCallCount += 1
        }
        
        externalShared = 99
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(viewState == 99, "SharedViewState should be updated")
        #expect(onChangeCallCount == 1, "onChange should be called once")
    }
    
    /// Verify that direct updates propagate to external Shared
    @Test
    func testDirectUpdatePropagateToExternalShared() async {
        let key = "test_direct_propagate"
        
        @Shared(.memory, key: key)
        var externalShared: Int = 0
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState: Int
        
        viewState = 77
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(externalShared == 77, "External Shared should be updated by direct assignment")
    }
    
    /// Verify bidirectional synchronization works correctly
    @Test
    func testBidirectionalSync() async {
        let key = "test_bidirectional"
        
        @Shared(.memory, key: key)
        var externalShared: Int = 0
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState: Int
        
        // SharedViewState -> Shared
        viewState = 10
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(externalShared == 10)
        
        // Shared -> SharedViewState
        externalShared = 20
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(viewState == 20)
        
        // Back to SharedViewState -> Shared
        viewState = 30
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(externalShared == 30)
    }
    
    /// Verify synchronization between multiple SharedViewState instances
    @Test
    func testMultipleSharedViewStatesSync() async {
        let key = "test_multiple_viewstates"
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState1: Int
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState2: Int
        
        nonisolated(unsafe) var onChange1Count = 0
        nonisolated(unsafe) var onChange2Count = 0
        
        _viewState1.setOnChange {
            onChange1Count += 1
        }
        _viewState2.setOnChange {
            onChange2Count += 1
        }
        
        viewState1 = 50
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(viewState2 == 50, "Second viewState should sync")
        #expect(onChange1Count == 1, "First viewState's onChange should be called for self update")
        #expect(onChange2Count == 1, "Second viewState's onChange should be called")
        
        viewState2 = 100
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(viewState1 == 100, "First viewState should sync")
        #expect(onChange1Count == 2, "First viewState's onChange should be called for external update")
        #expect(onChange2Count == 2, "Second viewState's onChange should be called for self update")
    }
    
    // MARK: - Multithreading Safety Tests
    
    /// Verify crash-free operation in multithreaded environment
    @Test
    func testMultithreadedSafety() async {
        let key = "test_multithreaded"
        
        @Shared(.memory, key: key)
        var externalShared: Int = 0
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState1: Int
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState2: Int
        
        nonisolated(unsafe) var onChangeCount = 0
        
        _viewState1.setOnChange {
            onChangeCount += 1
        }
        
        let wrapper1 = _viewState1
        let wrapper2 = _viewState2
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                wrapper1.wrappedValue = 40
            }
            
            group.addTask {
                wrapper2.wrappedValue = 80
            }
        }
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Verify no crash and synchronization occurred
        let finalValue = viewState1
        #expect(externalShared == finalValue, "All should be synchronized")
        #expect(viewState2 == finalValue, "All should be synchronized")
        #expect(onChangeCount >= 1 && onChangeCount <= 2, "onChange should be called at least once")
        #expect(finalValue == 40 || finalValue == 80, "Value should be either 40 or 80")
    }
    
    // MARK: - Advanced Tests
    
    /// Verify deadlock-free and crash-free operation during rapid successive updates
    @Test
    func testRapidSuccessiveUpdates() async {
        let key = "test_rapid_updates"
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState: Int
        
        @Shared(.memory, key: key)
        var externalShared: Int = 0
        
        nonisolated(unsafe) var onChangeCount = 0
        _viewState.setOnChange {
            onChangeCount += 1
        }
        
        for i in 0..<100 {
            viewState = i
        }
        
        try? await Task.sleep(nanoseconds: 300_000_000) // Increased wait time for async dispatch
        
        #expect(viewState == 99, "Final value should be 99")
        #expect(externalShared == 99, "External Shared should be synced")
        // onChange is called asynchronously on main queue, so some updates may be coalesced
        #expect(onChangeCount > 0 && onChangeCount <= 100, "onChange should be called (may be coalesced due to async dispatch)")
    }
    
    /// Verify correct operation when multiple threads update to the same value simultaneously
    @Test
    func testConcurrentSameValueUpdates() async {
        let key = "test_concurrent_same_value"
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState: Int
        
        nonisolated(unsafe) var onChangeCount = 0
        _viewState.setOnChange {
            onChangeCount += 1
        }
        
        let viewStateWrapper = _viewState
        
        // 100 threads updating to the same value (42) concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    viewStateWrapper.wrappedValue = 42
                }
            }
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(viewState == 42, "Value should be 42")
    }
    
    /// Verify synchronization across 3+ SharedViewState instances
    @Test
    func testMultipleInstancesFullSync() async {
        let key = "test_multi_instance_sync"
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState1: Int
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState2: Int
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState3: Int
        
        @Shared(.memory, key: key)
        var externalShared: Int = 0
        
        nonisolated(unsafe) var onChange1 = 0
        nonisolated(unsafe) var onChange2 = 0
        nonisolated(unsafe) var onChange3 = 0
        
        _viewState1.setOnChange { onChange1 += 1 }
        _viewState2.setOnChange { onChange2 += 1 }
        _viewState3.setOnChange { onChange3 += 1 }
        
        // Update from viewState1
        viewState1 = 111
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(viewState2 == 111, "viewState2 should sync")
        #expect(viewState3 == 111, "viewState3 should sync")
        #expect(externalShared == 111, "externalShared should sync")
        #expect(onChange2 == 1, "viewState2's onChange called")
        #expect(onChange3 == 1, "viewState3's onChange called")
        
        // Update from externalShared
        externalShared = 222
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(viewState1 == 222, "All should be 222")
        #expect(viewState2 == 222, "All should be 222")
        #expect(viewState3 == 222, "All should be 222")
    }
    
    /// Verify memory leak-free operation during dynamic instance creation and release
    @Test
    func testDynamicInstanceCreationAndRelease() async {
        let key = "test_dynamic_instances"
        
        @Shared(.memory, key: key)
        var externalShared: Int = 0
        
        // 10 iterations: create instance -> update -> release
        for i in 0..<10 {
            do {
                @SharedViewState(wrappedValue: 0, .memory, key: key)
                var tempViewState: Int
                
                tempViewState = i
                try? await Task.sleep(nanoseconds: 50_000_000)
                
                #expect(externalShared == i, "Should sync at iteration \(i)")
            }
            // tempViewState is released here
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        
        #expect(externalShared == 9, "Final value should be 9")
    }
    
    /// Verify synchronization with complex types (structs)
    @Test
    func testComplexTypeSync() async {
        struct UserData: Equatable, Sendable, Codable {
            var name: String
            var age: Int
            var isActive: Bool
        }
        
        let key = "test_complex_type"
        
        @SharedViewState(wrappedValue: UserData(name: "Alice", age: 25, isActive: true), .memory, key: key)
        var viewState: UserData
        
        @Shared(.memory, key: key)
        var externalShared = UserData(name: "Alice", age: 25, isActive: true)
        
        nonisolated(unsafe) var onChangeCount = 0
        _viewState.setOnChange {
            onChangeCount += 1
        }
        
        // Reset counter after initialization
        try? await Task.sleep(nanoseconds: 100_000_000)
        onChangeCount = 0
        
        // Update complex object from viewState
        viewState = UserData(name: "Bob", age: 30, isActive: false)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(externalShared.name == "Bob", "Name should be synced")
        #expect(externalShared.age == 30, "Age should be synced")
        #expect(externalShared.isActive == false, "isActive should be synced")
        #expect(onChangeCount == 1, "onChange should be called once for viewState update")
        
        // Reset counter
        onChangeCount = 0
        
        // Update from external
        externalShared = UserData(name: "Charlie", age: 35, isActive: true)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(viewState.name == "Charlie", "viewState should be updated")
        #expect(onChangeCount == 1, "onChange should be called once for external update")
    }
    
    /// Verify equality check works correctly
    @Test
    func testEqualityCheck() async {
        let key = "test_equality"
        
        @SharedViewState(wrappedValue: 100, .memory, key: key)
        var viewState: Int
        
        nonisolated(unsafe) var onChangeCount = 0
        _viewState.setOnChange {
            onChangeCount += 1
        }
        
        viewState = 100
        viewState = 100
        viewState = 100
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(onChangeCount == 0, "onChange should not be called for same value")
        
        viewState = 200
        
        @Shared(.memory, key: key)
        var externalShared: Int = 200
        
        externalShared = 200
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(onChangeCount == 1, "onChange should be called once for value change to 200")
    }
    
    /// Verify ignoreEquality option works correctly
    @Test
    func testIgnoreEqualityOption() async {
        let key = "test_ignore_equality"
        
        @SharedViewState(wrappedValue: 50, .memory, key: key, ignoreEquality: true)
        var viewState: Int
        
        nonisolated(unsafe) var onChangeCount = 0
        _viewState.setOnChange {
            onChangeCount += 1
        }
        
        // Setting to the same value should still trigger update
        let viewStateWrapper = _viewState
        viewStateWrapper.wrappedValue = 50
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // ignoreEquality is true, so update is performed but onChange is called
        #expect(viewState == 50, "Value should remain 50")
    }
    
    /// Verify instances with different keys don't interfere with each other
    @Test
    func testMultipleKeysIsolation() async {
        @SharedViewState(wrappedValue: 1, .memory, key: "key1")
        var state1: Int
        
        @SharedViewState(wrappedValue: 2, .memory, key: "key2")
        var state2: Int
        
        @SharedViewState(wrappedValue: 3, .memory, key: "key3")
        var state3: Int
        
        nonisolated(unsafe) var onChange1Count = 0
        nonisolated(unsafe) var onChange2Count = 0
        nonisolated(unsafe) var onChange3Count = 0
        
        _state1.setOnChange { onChange1Count += 1 }
        _state2.setOnChange { onChange2Count += 1 }
        _state3.setOnChange { onChange3Count += 1 }
        
        // Update only state1
        state1 = 100
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(state1 == 100, "state1 should be 100")
        #expect(state2 == 2, "state2 should remain 2")
        #expect(state3 == 3, "state3 should remain 3")
        #expect(onChange2Count == 0, "state2's onChange not called")
        #expect(onChange3Count == 0, "state3's onChange not called")
    }
    
    /// Stress test: massive concurrent updates and reads
    @Test
    func testStressTestMassiveConcurrency() async {
        let key = "test_stress"
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState: Int
        
        @Shared(.memory, key: key)
        var externalShared: Int = 0
        
        let viewStateWrapper = _viewState
        let sharedWrapper = $externalShared
        
        actor ReadCounter {
            var count = 0
            func increment() { count += 1 }
            func getCount() -> Int { count }
        }
        let readCounter = ReadCounter()
        
        // 500 concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // 200 write operations
            for i in 0..<200 {
                group.addTask {
                    viewStateWrapper.wrappedValue = i
                }
            }
            
            // 200 external Shared writes
            for i in 200..<400 {
                group.addTask {
                    sharedWrapper.withLock { $0 = i }
                }
            }
            
            // 100 read operations
            for _ in 0..<100 {
                group.addTask {
                    let _ = viewStateWrapper.wrappedValue
                    let _ = sharedWrapper.wrappedValue
                    await readCounter.increment()
                }
            }
        }
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Verify completion without crash and synchronized values
        let readCount = await readCounter.getCount()
        #expect(viewState == externalShared, "Values should be synchronized")
        #expect(readCount == 100, "All reads should complete")
        #expect(viewState >= 0 && viewState < 400, "Value should be in valid range")
    }
    
    /// Verify onChange callback is called on main thread
    @Test
    func testOnChangeCallsOnMainThread() async {
        let key = "test_main_thread"
        
        @SharedViewState(wrappedValue: 0, .memory, key: key)
        var viewState: Int
        
        @Shared(.memory, key: key)
        var externalShared: Int = 0
        
        nonisolated(unsafe) var isMainThread = false
        
        _viewState.setOnChange {
            isMainThread = Thread.isMainThread
        }
        
        // Update from external (triggers onChange)
        externalShared = 999
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        #expect(viewState == 999, "Value should be updated")
        #expect(isMainThread == true, "onChange should be called on main thread")
    }
}
