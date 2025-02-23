//
//  EmitTest.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/23/25.
//

import Testing
import Foundation
@testable import ReactableKit

struct EmitTest {
    @Test func testEmitCountIncrement() {
        @Emit var number: Int = 0
        
        #expect($number.count == 0, "Initial count should be 0.")
        number = 5
        #expect($number.count == 1, "Count should be 1 after the first change.")
        number = 10
        #expect($number.count == 2, "Count should be 2 after the second change.")
        // Even if the value is the same, didSet is called and count increments.
        number = 10
        #expect($number.count == 3, "Count should increase even when assigning the same value.")
    }
}
