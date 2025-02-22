//
//  CounterReactableTest.swift
//  ExmapleAppTests
//
//  Created by Jeehoon Son on 2/21/25.
//

import Testing
import ReactableKit

struct CounterReactableTest {

    @Test
    func increase() async {
        let stub = Stub(CounterReactable())
        
        await stub.action(.increase)
        await stub.action(.increase)
        #expect(stub.currentState.count == 3)
        
        await stub.action(.decrease)
        #expect(stub.currentState.count == 2)
        
        await stub.action(.decrease)
        #expect(stub.currentState.count == 1)
        
        await stub.action(.multiply(3))
        #expect(stub.currentState.count == 3)
        
        await stub.action(.runTest)
        #expect(stub.currentState.count1 == 30)
    }

}
