//
//  ManagedReference.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/30/25.
//

import Foundation
import Combine
import UIKit

// MARK: - NSRecursiveLock Extension

extension NSRecursiveLock {
    @discardableResult
    func withLock<R>(_ body: () throws -> R) rethrows -> R {
        lock()
        defer { unlock() }
        return try body()
    }
}

// MARK: - Reference

protocol Reference<Value>: AnyObject, Sendable {
    associatedtype Value
    
    var id: ObjectIdentifier { get }
    var wrappedValue: Value { get }
    var publisher: AnyPublisher<Value, Never> { get }
}

// MARK: - MutableReference

protocol MutableReference<Value>: Reference, Equatable {
    var key: String { get set }
    func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R
}

// MARK: - PersistentReference

final class PersistentReference<Value>: MutableReference, @unchecked Sendable {
    var key: String
    private let storage: StorageType
    private let lock = NSRecursiveLock()

    private var value: Value
    private var _referenceCount = 0
    private var _isReleasing = false

    var id: ObjectIdentifier { ObjectIdentifier(self) }

    var wrappedValue: Value {
        lock.withLock { value }
    }

    var publisher: AnyPublisher<Value, Never> {
        // Get global publisher from ManagedMemoryStorage
        let currentValue = lock.withLock { self.value }
        return ManagedMemoryStorage.shared.publisher(forKey: key, valueType: Value.self)
            .prepend(currentValue)
            .handleEvents(
                receiveSubscription: { [weak self] (_: Subscription) in self?.retain() },
                receiveCompletion: { [weak self] (_: Subscribers.Completion<Never>) in self?.release() },
                receiveCancel: { [weak self] in self?.release() }
            )
            .eraseToAnyPublisher()
    }

    init(key: String, storage: StorageType, initialValue: Value) {
        self.key = key
        self.storage = storage
        self.value = initialValue
    }

    deinit {
        // Global subject is managed by ManagedMemoryStorage
    }

    func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        // CRITICAL: Extract all data inside lock, then release lock before calling external code
        let (result, newValue, key) = try lock.withLock { () -> (R, Value, String) in
            let result = try body(&value)
            return (result, self.value, self.key)
        }

        // All operations below happen OUTSIDE the lock to prevent deadlock
        self.saveToStorage(newValue)
        ManagedMemoryStorage.shared.notifyValueChange(newValue, forKey: key)
        ManagedMemoryStorage.shared.syncCachedValue(newValue, forKey: key)

        return result
    }

    func retain() {
        lock.withLock { _referenceCount += 1 }
    }

    func release() {
        let shouldRelease = lock.withLock {
            guard !_isReleasing else { return false }

            _referenceCount -= 1
            let shouldRelease = _referenceCount <= 0

            if shouldRelease {
                _isReleasing = true
            }

            return shouldRelease
        }

        guard shouldRelease else { return }
        // Call outside lock to prevent deadlock
        ManagedMemoryStorage.shared.removeReference(forKey: key)
    }
    
    private func saveToStorage(_ value: Value) {
        switch storage {
        case let .userDefaults(userDefaults):
            guard let encodableValue = value as? Codable else { return }
            let encoded = try? JSONEncoder().encode(encodableValue)
            userDefaults.set(encoded, forKey: key)
            
        case let .file(directory, path):
            guard let encodableValue = value as? Codable else { return }
            guard let url = getFileURL(directory: directory, path: path, key: key) else { return }
            let encoded = try? JSONEncoder().encode(encodableValue)
            
            do {
                try createFolderIfNeeded(for: url)
                try encoded?.write(to: url)
            } catch {
                print("Failed to save persistent reference to file", error)
            }
            
        default: break
        }
    }
    
    private func getFileURL(directory: FileManager.SearchPathDirectory, path: String?, key: String) -> URL? {
        let fileManager = FileManager.default
        guard let directoryURL = fileManager.urls(for: directory, in: .userDomainMask).first else {
            return nil
        }
        
        var folderURL = directoryURL
        if let path {
            folderURL = folderURL.appendingPathComponent(path)
        } else {
            folderURL = folderURL.appendingPathComponent("Reactable")
        }
        
        return folderURL.appendingPathComponent("\(key).json")
    }
    
    private func createFolderIfNeeded(for fileURL: URL) throws {
        let folderURL = fileURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    static func == (lhs: PersistentReference, rhs: PersistentReference) -> Bool {
        lhs === rhs
    }
}

// MARK: - ManagedReference

final class ManagedReference<Value>: MutableReference, @unchecked Sendable {
    private let base: PersistentReference<Value>
    
    var id: ObjectIdentifier { base.id }
    var wrappedValue: Value { base.wrappedValue }
    var publisher: AnyPublisher<Value, Never> { base.publisher }
    var key: String {
        get { base.key }
        set { base.key = newValue }
    }
    
    init(_ base: PersistentReference<Value>) {
        base.retain()
        self.base = base
    }
    
    deinit {
        base.release()
    }
    
    func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        try base.withLock(body)
    }
    
    static func == (lhs: ManagedReference, rhs: ManagedReference) -> Bool {
        lhs.base == rhs.base
    }
}

// MARK: - ManagedMemoryStorage

final class ManagedMemoryStorage: @unchecked Sendable {
    static let shared = ManagedMemoryStorage()

    struct Entry {
        var cachedValue: Any
        var reference: Any? // PersistentReference<T>
        var isSingleton: Bool
        var subject: Any? // PassthroughSubject<T, Never>
    }

    private var storage: [String: Entry] = [:]
    private let lock = NSRecursiveLock()

    private init() {
        setupAutomaticCleanup()
    }
    
    func value<Value>(
        forKey key: String,
        storage: StorageType,
        defaultValue: Value
    ) -> ManagedReference<Value> {
        lock.withLock {
            if let entry = self.storage[key],
               let persistentReference = entry.reference as? PersistentReference<Value>
            {
                return ManagedReference(persistentReference)
            }

            // Load from storage if available
            let storedValue: Value = switch storage {
            case .memorySingleton:
                if let entry = self.storage[key], let cached = entry.cachedValue as? Value {
                    cached
                } else {
                    defaultValue
                }
            default:
                loadFromStorage(storage: storage, key: key, defaultValue: defaultValue)
            }

            let persistentReference = PersistentReference(
                key: key,
                storage: storage,
                initialValue: storedValue
            )

            // Create or get existing subject for this key
            let subject: PassthroughSubject<Value, Never>
            if let entry = self.storage[key], let existingSubject = entry.subject as? PassthroughSubject<Value, Never> {
                subject = existingSubject
            } else {
                subject = PassthroughSubject<Value, Never>()
            }

            let entry = Entry(
                cachedValue: storedValue,
                reference: persistentReference,
                isSingleton: storage.isSingleton,
                subject: subject
            )
            self.storage[key] = entry

            return ManagedReference(persistentReference)
        }
    }
    
    func publisher<Value>(forKey key: String, valueType: Value.Type) -> AnyPublisher<Value, Never> {
        lock.withLock {
            if let entry = storage[key], let subject = entry.subject as? PassthroughSubject<Value, Never> {
                return subject.eraseToAnyPublisher()
            } else {
                let subject = PassthroughSubject<Value, Never>()

                if var entry = storage[key] {
                    entry.subject = subject
                    storage[key] = entry
                } else {
                    let entry = Entry(
                        cachedValue: Optional<Value>.none as Any,
                        reference: nil,
                        isSingleton: false,
                        subject: subject
                    )
                    storage[key] = entry
                }

                return subject.eraseToAnyPublisher()
            }
        }
    }
    
    func notifyValueChange<Value>(_ value: Value, forKey key: String) {
        // CRITICAL: Get subject inside lock, then send OUTSIDE lock to prevent deadlock
        let subject: PassthroughSubject<Value, Never>? = lock.withLock {
            guard let entry = storage[key] else { return nil }
            return entry.subject as? PassthroughSubject<Value, Never>
        }

        // Send outside lock - PassthroughSubject.send() is not thread-safe but we serialize access
        subject?.send(value)
    }
    
    func removeReference(forKey key: String) {
        // CRITICAL: Get subject inside lock, complete OUTSIDE lock
        let subjectToComplete: PassthroughSubject<Any, Never>? = lock.withLock {
            guard var entry = storage[key] else { return nil }
            if entry.isSingleton {
                // Keep cachedValue and subject, drop only the reference
                entry.reference = nil
                storage[key] = entry
                return nil
            } else {
                // Get subject for completion
                let subject = entry.subject as? PassthroughSubject<Any, Never>
                storage.removeValue(forKey: key)
                return subject
            }
        }

        // Complete subject outside lock
        subjectToComplete?.send(completion: .finished)
    }
    
    func cleanupUnusedReferences() {
        // CRITICAL: Collect subjects inside lock, complete OUTSIDE lock
        let subjectsToComplete: [PassthroughSubject<Any, Never>] = lock.withLock {
            let keysToRemove = storage.compactMap { key, entry in
                // For singleton entries, keep cached values even if reference is nil
                (entry.reference == nil && !entry.isSingleton) ? key : nil
            }

            guard !keysToRemove.isEmpty else { return [] }

            var subjects: [PassthroughSubject<Any, Never>] = []
            for key in keysToRemove {
                if let entry = storage[key], let subject = entry.subject as? PassthroughSubject<Any, Never> {
                    subjects.append(subject)
                }
                storage.removeValue(forKey: key)
            }
            return subjects
        }

        // Complete subjects outside lock
        for subject in subjectsToComplete {
            subject.send(completion: .finished)
        }
    }
    
    func removeAll() {
        // CRITICAL: Collect subjects inside lock, complete OUTSIDE lock
        let subjectsToComplete: [PassthroughSubject<Any, Never>] = lock.withLock {
            var subjects: [PassthroughSubject<Any, Never>] = []
            for (_, entry) in storage {
                if let subject = entry.subject as? PassthroughSubject<Any, Never> {
                    subjects.append(subject)
                }
            }
            storage.removeAll()
            return subjects
        }

        // Complete subjects outside lock
        for subject in subjectsToComplete {
            subject.send(completion: .finished)
        }
    }
    
    private func loadFromStorage<Value>(storage: StorageType, key: String, defaultValue: Value) -> Value {
        switch storage {
        case let .userDefaults(userDefaults):
            guard let data = userDefaults.data(forKey: key) else {
                return userDefaults.object(forKey: key) as? Value ?? defaultValue
            }
            guard let codableDefault = defaultValue as? Codable else {
                return defaultValue
            }
            return decode(data, defaultValue: codableDefault) as? Value ?? defaultValue
            
        case let .file(directory, path):
            guard let url = getFileURL(directory: directory, path: path, key: key),
                  let data = try? Data(contentsOf: url)
            else {
                return defaultValue
            }
            guard let codableDefault = defaultValue as? Codable else {
                return defaultValue
            }
            return decode(data, defaultValue: codableDefault) as? Value ?? defaultValue
            
        case .memorySingleton:
            return defaultValue
            
        default:
            return defaultValue
        }
    }

    func syncCachedValue<Value>(_ value: Value, forKey key: String) {
        lock.withLock {
            guard var entry = storage[key] else { return }
            entry.cachedValue = value as Any
            storage[key] = entry
        }
    }
    
    private func decode<T: Codable>(_ data: Data, defaultValue: T) -> T {
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            return defaultValue
        }
        return decoded
    }
    
    private func getFileURL(directory: FileManager.SearchPathDirectory, path: String?, key: String) -> URL? {
        let fileManager = FileManager.default
        guard let directoryURL = fileManager.urls(for: directory, in: .userDomainMask).first else {
            return nil
        }
        
        var folderURL = directoryURL
        if let path {
            folderURL = folderURL.appendingPathComponent(path)
        } else {
            folderURL = folderURL.appendingPathComponent("Reactable")
        }
        
        return folderURL.appendingPathComponent("\(key).json")
    }
    
    private func setupAutomaticCleanup() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cleanupUnusedReferences()
        }
    }
}
