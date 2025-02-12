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
    case file(directory: FileManager.SearchPathDirectory = .documentDirectory, path: String? = nil)
    case memory
}

// MARK: - @Shared (Unified)

extension Shared: @unchecked Sendable where Value: Sendable {}

@propertyWrapper
public struct Shared<Value: Equatable>: CustomStringConvertible {
    private let key: String
    private let storage: StorageType
    private let subject: CurrentValueSubject<Value, Never>
    
    public var wrappedValue: Value {
        get { subject.value }
        set {
            guard newValue != wrappedValue else { return }
            subject.send(newValue)
            saveToStorage(newValue)
        }
    }
    
    public var projectedValue: Shared<Value> { self }
    
    public var description: String {
        "\(self.wrappedValue)"
    }
    
    public var publisher: AnyPublisher<Value, Never> { subject.eraseToAnyPublisher() }
    
    public init(wrappedValue defaultValue: Value, _ storage: StorageType = .memory, key: String? = nil) {
        let prefix = "reactable_shared"
        let inferredKey = key ?? "\(prefix)_\(String(reflecting: Value.self))"

        if (storage == .file() || storage == .userDefaults()) && !(defaultValue is Codable) {
            fatalError("❌ Value must conform to Codable when using .file or .userDefaults storage.")
        }
        
        self.key = inferredKey
        self.storage = storage
        
        if let existingSubject = MemoryStorage.shared.get(forKey: inferredKey) as? CurrentValueSubject<Value, Never> {
            self.subject = existingSubject
        } else {
            let storedValue = Self.loadFromStorage(storage: storage, key: inferredKey, defaultValue: defaultValue)
            let newSubject = CurrentValueSubject<Value, Never>(storedValue)
            MemoryStorage.shared.set(newSubject, forKey: inferredKey)
            self.subject = newSubject
        }
    }
    
    // MARK: - Storage Handling

    private func saveToStorage(_ value: Value) {
        switch storage {
        case let .userDefaults(userDefaults):
            guard let encodableValue = value as? Codable else {
                fatalError("❌ Value must conform to Codable when using .userDefaults storage.")
            }
            let encoded = try? JSONEncoder().encode(encodableValue)
            userDefaults.set(encoded, forKey: key)

        case let .file(directory, path):
            guard let encodableValue = value as? Codable else {
                fatalError("❌ Value must conform to Codable when using .file storage.")
            }
            guard let url = Self.getFileURL(directory: directory, path: path, key: key) else { return }
            let encoded = try? JSONEncoder().encode(encodableValue)

            do {
                try Self.createFolderIfNeeded(for: url)
                try encoded?.write(to: url)
            } catch {
                print("❌ Failed to save file: \(error.localizedDescription)")
            }

        default: break
        }
    }

    public func removeFromStorage() {
        switch storage {
        case let .userDefaults(userDefaults):
            userDefaults.removeObject(forKey: key)

        case let .file(directory, path):
            guard let url = Self.getFileURL(directory: directory, path: path, key: key) else { return }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("❌ Failed to remove file: \(error.localizedDescription)")
            }

        default: break
        }
    }

    private static func loadFromStorage(storage: StorageType, key: String?, defaultValue: Value) -> Value {
        guard let key else { return defaultValue }

        switch storage {
        case let .userDefaults(userDefaults):
            guard let data = userDefaults.data(forKey: key) else {
                return userDefaults.object(forKey: key) as? Value ?? defaultValue
            }
            guard let codableDefault = defaultValue as? Codable else {
                fatalError("❌ Value must conform to Codable when using .userDefaults storage.")
            }
            return decode(data, defaultValue: codableDefault) as? Value ?? defaultValue

        case let .file(directory, path):
            guard let url = Self.getFileURL(directory: directory, path: path, key: key),
                  let data = try? Data(contentsOf: url) else {
                return defaultValue
            }
            guard let codableDefault = defaultValue as? Codable else {
                fatalError("❌ Value must conform to Codable when using .file storage.")
            }
            return decode(data, defaultValue: codableDefault) as? Value ?? defaultValue

        default:
            return defaultValue
        }
    }

    private static func decode<T: Codable>(_ data: Data, defaultValue: T) -> T {
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            return defaultValue
        }
        return decoded
    }

    private static func createFolderIfNeeded(for fileURL: URL) throws {
        let folderURL = fileURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private static func getFileURL(directory: FileManager.SearchPathDirectory, path: String?, key: String) -> URL? {
        let fileManager = FileManager.default
        guard let directoryURL = fileManager.urls(for: directory, in: .userDomainMask).first else {
            return nil
        }

        var folderURL = directoryURL
        if let path = path {
            folderURL = folderURL.appendingPathComponent(path)
        } else {
            folderURL = folderURL.appendingPathComponent("Reactable")
        }

        return folderURL.appendingPathComponent("\(key).json")
    }
}

// MARK: - Memory Storage (Singleton)

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
