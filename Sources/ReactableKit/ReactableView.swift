//
//  ReactableView.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 2/26/25.
//

import Foundation
import Combine

private enum WeakCache {
    nonisolated(unsafe) static let reactable = WeakKeyDictionary<AnyObject, Any>()
}

@MainActor
public protocol ReactableView: AnyObject {
    associatedtype R: Reactable
    var reactable: R? { get set }
    var cancellables: Set<AnyCancellable> { get set }
    func bind(reactable: R)
}

public extension ReactableView {
    var reactable: R? {
        get { WeakCache.reactable.value(forKey: self) as? R }
        set {
            WeakCache.reactable.setValue(newValue, forKey: self)
            self.cancellables.forEach { $0.cancel() }
            self.cancellables = .init()
            if let newValue { self.bind(reactable: newValue) }
        }
    }
}
