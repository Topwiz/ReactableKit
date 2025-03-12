//
//  StrongKeyDictionaryTests.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 3/13/25.
//

import Foundation
import Testing
@testable import ReactableKit

struct StrongKeyDictionaryTests {

    // Test that a value can be set and retrieved for a given key
    @Test
    func testSetValueAndGetValue() {
        let dictionary = StrongKeyDictionary<String, String>()
        let key = "testKey"
        let value = "testValue"
        
        dictionary.setValue(value, forKey: key)
        #expect(dictionary.value(forKey: key) == value)
    }

    // Test that a default value is returned if the key does not exist
    @Test
    func testDefaultValue() {
        let dictionary = StrongKeyDictionary<String, String>()
        let key = "testKey"
        let defaultValue = "defaultValue"
        
        #expect(dictionary.value(forKey: key, default: defaultValue) == defaultValue)
    }

    // Test that a value can be force casted to a specific type
    @Test
    func testForceCastedValue() {
        let dictionary = StrongKeyDictionary<String, Any>()
        let key = "testKey"
        let value = "testValue"
        
        dictionary.setValue(value, forKey: key)
        #expect(dictionary.forceCastedValue(forKey: key, default: value) == value)
    }

    // Test that a value is removed when set to nil
    @Test
    func testRemoveValue() {
        let dictionary = StrongKeyDictionary<String, String>()
        let key = "testKey"
        let value = "testValue"
        
        dictionary.setValue(value, forKey: key)
        #expect(dictionary.value(forKey: key) == value)
        
        dictionary.setValue(nil, forKey: key)
        #expect(dictionary.value(forKey: key) == nil)
    }
}
