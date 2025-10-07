//
//  SharedViewState.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 8/29/25.
//

import Foundation
import Combine
import SwiftUI

@propertyWrapper
public final class SharedViewState<Value: Equatable & Sendable>: Equatable, @unchecked Sendable, CustomStringConvertible, PublishedWrapper {
    private let syncLock = NSRecursiveLock()
    private var _value: Value
    @Shared private var sharedValue: Value
    private var ignoreEquality: Bool
    private var onChange: (() -> Void)?
    private var animation: Animation?
    private var cancellable: AnyCancellable?
    
    private var _isSyncing = false
    private var _lastSetValue: Value?
    private var _isInitialized = false
    
    private var isSyncing: Bool {
        get { self.syncLock.withLock { self._isSyncing } }
        set { self.syncLock.withLock { self._isSyncing = newValue } }
    }
    private var lastSetValue: Value? {
        get { self.syncLock.withLock { self._lastSetValue } }
        set { self.syncLock.withLock { self._lastSetValue = newValue } }
    }
    private var isInitialized: Bool {
        get { self.syncLock.withLock { self._isInitialized } }
        set { self.syncLock.withLock { self._isInitialized = newValue } }
    }

    public var wrappedValue: Value {
        get {
            self.syncLock.withLock { self._value }
        }
        set {
            let shouldUpdate = self.syncLock.withLock { () -> Bool in
                if !self.ignoreEquality && self._value == newValue {
                    return false
                }
                
                guard !self._isSyncing else {
                    return false
                }
                
                self._isSyncing = true
                self._value = newValue
                self._lastSetValue = newValue
                
                return true
            }
            
            guard shouldUpdate else { return }
            
            // Update shared value outside of lock to prevent deadlock
            self.sharedValue = newValue
            
            self.syncLock.withLock {
                self._isSyncing = false
            }
            
            // Trigger onChange for self updates to notify SwiftUI
            self.triggerOnChange()
        }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }

    public var description: String {
        "\(self.wrappedValue)"
    }

    public init(
        wrappedValue: Value,
        _ storage: StorageType = .memory,
        key: String? = nil,
        ignoreEquality: Bool = false,
        animation: Animation? = nil
    ) {
        self.ignoreEquality = ignoreEquality
        self.animation = animation

        @Shared(storage, key: key) var sharedValue: Value = wrappedValue
        self._value = $sharedValue.wrappedValue
        self._sharedValue = $sharedValue
        self._lastSetValue = $sharedValue.wrappedValue
        
        self.observeShared()
        
        self.syncLock.withLock {
            self._isInitialized = true
        }
    }

    public init(
        wrappedValue: Shared<Value>,
        ignoreEquality: Bool = false,
        animation: Animation? = nil
    ) {
        self.ignoreEquality = ignoreEquality
        self.animation = animation
        self._value = wrappedValue.wrappedValue
        self._sharedValue = wrappedValue
        self._lastSetValue = wrappedValue.wrappedValue
        
        self.observeShared()
        
        self.syncLock.withLock {
            self._isInitialized = true
        }
    }

    private func observeShared() {
        self.cancellable = self.$sharedValue.publisher
            .sink { [weak self] newValue in
                guard let self else { return }
                
                let shouldTriggerOnChange = self.syncLock.withLock { () -> Bool in
                    guard self._isInitialized else {
                        return false
                    }
                    
                    // Skip if this change came from wrappedValue setter
                    guard !self._isSyncing else {
                        return false
                    }
                    
                    if !self.ignoreEquality && self._value == newValue {
                        return false
                    }
                    
                    self._isSyncing = true
                    self._value = newValue
                    self._isSyncing = false
                    
                    return true
                }
                
                if shouldTriggerOnChange {
                    self.triggerOnChange()
                }
            }
    }
    
    private func triggerOnChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let animation = self.animation {
                withAnimation(animation) {
                    self.onChange?()
                }
            } else {
                self.onChange?()
            }
        }
    }

    public func setOnChange(_ handler: @escaping () -> Void) {
        self.onChange = handler
    }

    public static func == (lhs: SharedViewState<Value>, rhs: SharedViewState<Value>) -> Bool {
        if lhs === rhs { return true }
        guard lhs.$sharedValue == rhs.$sharedValue else { return false }
        let lhsLastSet = lhs.lastSetValue
        let rhsLastSet = rhs.lastSetValue
        if let lhsLast = lhsLastSet, let rhsLast = rhsLastSet {
            return lhsLast == rhsLast
        }
        return lhs.syncLock.withLock { lhs._value } == rhs.syncLock.withLock { rhs._value }
    }
}
