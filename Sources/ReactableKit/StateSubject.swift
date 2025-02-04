//
//  StateSubject.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/3/25.
//

import Foundation

final class StateSubject<State>: ObservableObject {
    private let subject: CurrentValueSubject<State, Never>

    var value: State {
        get { subject.value }
        set { subject.send(newValue) }
    }

    var publisher: AnyPublisher<State, Never> {
        subject.eraseToAnyPublisher()
    }
    
    func send(_ value: State) {
        subject.send(value)
    }

    init(initialState: State) {
        self.subject = CurrentValueSubject<State, Never>(initialState)
    }
}
