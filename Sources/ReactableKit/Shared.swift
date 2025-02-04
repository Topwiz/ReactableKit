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

// MARK: - Property Wrapper: Shared
@propertyWrapper
public struct Shared<Value: Codable & Equatable>: @unchecked Sendable, Equatable {
    private let key: String
    private let storage: StorageType
    private let subject: CurrentValueSubject<Value, Never>
    private var defaultValue: Value
    
    public var projectedValue: Shared<Value> { self }
    
    public var wrappedValue: Value {
        get { subject.value }
        set {
            guard newValue != self.wrappedValue else { return }
            subject.send(newValue)
            saveToStorage(newValue)
        }
    }
    
    public var publisher: AnyPublisher<Value, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(
        wrappedValue defaultValue: Value,
        _ storage: StorageType,
        key: String? = nil,
        file: StaticString = #file,
        function: StaticString = #function
    ) {
        let prefix = "reactable_shared"
        var inferredKey = "\(prefix)_\(Self.generateKey(for: Value.self))"
        if let key {
            inferredKey = "\(prefix)_\(key)"
        }
        self.key = inferredKey
        self.storage = storage
        self.defaultValue = defaultValue
        let storageValue = Self.loadFromStorage(storage: storage, key: inferredKey) ?? defaultValue
        self.subject = Cache.sharedProperty.forceCastedValue(forKey: inferredKey, default: CurrentValueSubject<Value, Never>(storageValue))
    }
    
    public func remove() {
        self.removeFromStorage()
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

        case .memory:
            MemoryStorage.shared.set(value, forKey: key)
        }
    }

    func removeFromStorage() {
        switch storage {
        case let .userDefaults(userDefaults):
            userDefaults.removeObject(forKey: key)

        case let .file(directory):
            guard let url = Self.getFileURL(directory: directory, key: key) else { return }
            try? FileManager.default.removeItem(at: url)

        case .memory:
            MemoryStorage.shared.remove(forKey: key)
        }
    }

    static func loadFromStorage(storage: StorageType, key: String?) -> Value? {
        guard let key else { return nil }
        switch storage {
        case let .userDefaults(userDefaults):
            guard let data = userDefaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(Value.self, from: data) else { return nil }
            return decoded

        case let .file(directory):
            guard let url = Self.getFileURL(directory: directory, key: key),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(Value.self, from: data) else { return nil }
            return decoded

        case .memory:
            return MemoryStorage.shared.get(forKey: key)
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
    
    static func generateKey(for type: Any.Type) -> String {
        return String(reflecting: type)
    }
    
    public static func == (lhs: Shared<Value>, rhs: Shared<Value>) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}

// MARK: - Memory Storage

final class MemoryStorage {
    nonisolated(unsafe) static let shared = MemoryStorage()
    private var storage: [String: Any] = [:]
    private let lock = NSLock()

    private init() {}

    func set<T: Codable>(_ value: T, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    func get<T: Codable>(forKey key: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key] as? T
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
