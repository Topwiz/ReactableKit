//
//  WeakKeyDictionaryTests.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 3/13/25.
//

import Foundation
import Testing
@testable import ReactableKit

struct WeakKeyDictionaryTests {

    // Test that a value can be set and retrieved for a given key
    @Test
    func testSetValueAndGetValue() {
        let dictionary = WeakKeyDictionary<NSObject, String>()
        let key = NSObject()
        let value = "testValue"
        
        dictionary.setValue(value, forKey: key)
        #expect(dictionary.value(forKey: key) == value)
    }

    // Test that a value is removed when the key is deallocated
    @Test
    func testValueRemovalOnKeyDeallocation() {
        let dictionary = WeakKeyDictionary<NSObject, String>()
        var key: NSObject? = NSObject()
        let value = "testValue"
        
        dictionary.setValue(value, forKey: key!)
        let newValue = dictionary.value(forKey: key!)
        #expect(newValue == value)
        #expect(dictionary.storageCount == 1)
        key = nil
        #expect(dictionary.storageCount == 0)
    }

    // Test that a default value is returned if the key does not exist
    @Test
    func testDefaultValue() {
        let dictionary = WeakKeyDictionary<NSObject, String>()
        let key = NSObject()
        let defaultValue = "defaultValue"
        
        #expect(dictionary.value(forKey: key, default: defaultValue) == defaultValue)
    }

    // Test that a value can be force casted to a specific type
    @Test
    func testForceCastedValue() {
        let dictionary = WeakKeyDictionary<NSObject, Any>()
        let key = NSObject()
        let value = "testValue"
        
        dictionary.setValue(value, forKey: key)
        #expect(dictionary.forceCastedValue(forKey: key, default: value) == value)
    }
}
