//
//  Shared.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 1/28/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Storage Type Enum

public enum StorageType: Hashable {
    case userDefaults(UserDefaults = .standard)
    case file(directory: FileManager.SearchPathDirectory = .documentDirectory)
    case memory
}

// MARK: - Shared Protocol

protocol SharedProtocol {
    associatedtype Value
    var key: String { get }
    var storage: StorageType { get }
    var subject: CurrentValueSubject<Value, Never> { get }
    var publisher: AnyPublisher<Value, Never> { get }
    var value: Value { get }
}

// MARK: - @Shared

@propertyWrapper
public struct Shared<Value: Equatable>: SharedProtocol {
    let key: String
    let storage: StorageType
    let subject: CurrentValueSubject<Value, Never>
    var value: Value { subject.value }
    
    public var wrappedValue: Value {
        get { subject.value }
        set {
            guard newValue != wrappedValue else { return }
            subject.send(newValue)
        }
    }
    
    public var projectedValue: Shared<Value> { self }
    
    public var publisher: AnyPublisher<Value, Never> { subject.eraseToAnyPublisher() }
    
    public init(wrappedValue defaultValue: Value, key: String? = nil) {
        let prefix = "reactable_shared"
        let inferredKey = key ?? "\(prefix)_\(String(reflecting: Value.self))"
        
        self.key = inferredKey
        self.storage = .memory
        
        if let existingSubject = MemoryStorage.shared.get(forKey: inferredKey) as? CurrentValueSubject<Value, Never> {
            self.subject = existingSubject
        } else {
            let newSubject = CurrentValueSubject<Value, Never>(defaultValue)
            MemoryStorage.shared.set(newSubject, forKey: inferredKey)
            self.subject = newSubject
        }
    }
}

// MARK: - @SharedCodable

@propertyWrapper
public struct SharedCodable<Value: Codable & Equatable>: SharedProtocol {
    let key: String
    let storage: StorageType
    let subject: CurrentValueSubject<Value, Never>
    var value: Value { subject.value }
    
    public var wrappedValue: Value {
        get { subject.value }
        set {
            guard newValue != wrappedValue else { return }
            subject.send(newValue)
            saveToStorage(newValue)
        }
    }
    
    public var projectedValue: SharedCodable<Value> { self }
    
    public var publisher: AnyPublisher<Value, Never> { self.subject.eraseToAnyPublisher() }
    
    public init(wrappedValue defaultValue: Value, _ storage: StorageType, key: String? = nil) {
        guard storage != .memory else {
            fatalError("SharedCodable can not be used with MemoryStorage. Use @Shared property wrapper.")
        }
        
        let prefix = "reactable_shared"
        let inferredKey = key ?? "\(prefix)_\(String(reflecting: Value.self))"
        
        self.key = inferredKey
        self.storage = storage
        if let existingSubject = MemoryStorage.shared.get(forKey: inferredKey) as? CurrentValueSubject<Value, Never> {
            self.subject = existingSubject
        } else {
            let storageValue = Self.loadFromStorage(storage: storage, key: inferredKey, defaultValue: defaultValue)
            let newSubject = CurrentValueSubject<Value, Never>(storageValue)
            MemoryStorage.shared.set(newSubject, forKey: inferredKey)
            self.subject = newSubject
        }
    }
    
    func saveToStorage(_ value: Value) {
        switch storage {
        case let .userDefaults(userDefaults):
            let encoded = try? JSONEncoder().encode(value)
            userDefaults.set(encoded, forKey: key)

        case let .file(directory):
            guard let url = Self.getFileURL(directory: directory, key: key) else { return }
            let encoded = try? JSONEncoder().encode(value)
            try? encoded?.write(to: url)

        default: break
        }
    }

    public func removeFromStorage() {
        switch storage {
        case let .userDefaults(userDefaults):
            userDefaults.removeObject(forKey: key)

        case let .file(directory):
            guard let url = Self.getFileURL(directory: directory, key: key) else { return }
            try? FileManager.default.removeItem(at: url)

        default: break
        }
    }

    static func loadFromStorage(storage: StorageType, key: String?, defaultValue: Value) -> Value {
        guard let key else { return defaultValue }
        switch storage {
        case let .userDefaults(userDefaults):
            guard let data = userDefaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(Value.self, from: data) else { return defaultValue }
            return decoded

        case let .file(directory):
            guard let url = Self.getFileURL(directory: directory, key: key),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(Value.self, from: data) else { return defaultValue }
            return decoded

        default:
            return defaultValue
        }
    }

    static func getFileURL(directory: FileManager.SearchPathDirectory, key: String) -> URL? {
        let fileManager = FileManager.default
        guard let directoryURL = fileManager.urls(for: directory, in: .userDomainMask).first else {
            return nil
        }

        let folderURL = directoryURL.appendingPathComponent("Reactable")
        let fileURL = folderURL.appendingPathComponent("\(key).json")

        if !fileManager.fileExists(atPath: folderURL.path) {
            do {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("❌ Failed: \(error.localizedDescription)")
                return nil
            }
        }

        return fileURL
    }
}

// MARK: - Memory Storage

final class MemoryStorage {
    nonisolated(unsafe) static let shared = MemoryStorage()
    private var storage: [String: Any] = [:]
    private let lock = NSLock()

    private init() {}

    func set(_ value: Any, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    func get(forKey key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func remove(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}
