//
//  ChildObserverChain.swift
//  ReactableKit
//
//  Created by Jeehoon Son on 3/12/26.
//

import Combine
import Foundation

private func optionalIdentityEquals<O: AnyObject>(_ lhs: O?, _ rhs: O?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil): return true
    case let (l?, r?): return ObjectIdentifier(l) == ObjectIdentifier(r)
    default: return false
    }
}

private func observeOptionalLeaf<R: Reactable & ObservableEvent>(
    _ leafPublisher: AnyPublisher<R?, Never>
) -> AnyPublisher<ObservableEventResult<R>, Never> {
    leafPublisher
        .removeDuplicates(by: optionalIdentityEquals)
        .map { leaf -> AnyPublisher<ObservableEventResult<R>, Never> in
            guard let leaf else { return Empty().eraseToAnyPublisher() }
            return R.observe()
                .filter { ObjectIdentifier(leaf) == $0.sourceId }
                .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
}

private func chainOptionalChild<Parent: Reactable, Child: Reactable & ObservableEvent>(
    parentPublisher: AnyPublisher<Parent?, Never>,
    keyPath: KeyPath<Parent.State, Child?>
) -> AnyPublisher<Child?, Never> {
    parentPublisher
        .removeDuplicates(by: optionalIdentityEquals)
        .map { parent -> AnyPublisher<Child?, Never> in
            guard let parent else { return Just(nil).eraseToAnyPublisher() }
            return parent.state
                .map { $0[keyPath: keyPath] }
                .prepend(parent.currentState[keyPath: keyPath])
                .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
}

private func observeNonOptionalDescendant<Parent: Reactable, Child: Reactable & ObservableEvent>(
    parentPublisher: AnyPublisher<Parent?, Never>,
    keyPath: KeyPath<Parent.State, Child>
) -> AnyPublisher<ObservableEventResult<Child>, Never> {
    parentPublisher
        .removeDuplicates(by: optionalIdentityEquals)
        .map { parent -> AnyPublisher<ObservableEventResult<Child>, Never> in
            guard let parent else { return Empty().eraseToAnyPublisher() }
            return parent.state
                .map { $0[keyPath: keyPath] }
                .prepend(parent.currentState[keyPath: keyPath])
                .removeDuplicates(by: { ObjectIdentifier($0) == ObjectIdentifier($1) })
                .map { child -> AnyPublisher<ObservableEventResult<Child>, Never> in
                    child.observe().eraseToAnyPublisher()
                }
                .switchToLatest()
                .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
}

public struct DirectChildChain<Root: Reactable, Leaf: Reactable & ObservableEvent> {
    weak var root: Root?
    let keyPath: KeyPath<Root.State, Leaf>
    
    public init(root: Root?, keyPath: KeyPath<Root.State, Leaf>) {
        self.root = root
        self.keyPath = keyPath
    }
    
    public func observe() -> AnyPublisher<ObservableEventResult<Leaf>, Never> {
        guard let root else { return Empty().eraseToAnyPublisher() }
        let childPublisher = root.state
            .map { $0[keyPath: keyPath] }
            .prepend(root.currentState[keyPath: keyPath])
            .removeDuplicates(by: { ObjectIdentifier($0) == ObjectIdentifier($1) })
        
        return childPublisher
            .map { child -> AnyPublisher<ObservableEventResult<Leaf>, Never> in
                child.observe().eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
    
    public func child<T: Reactable & ObservableEvent>(
        _ childKeyPath: KeyPath<Leaf.State, T>
    ) -> DirectChildChain2<Root, Leaf, T> {
        DirectChildChain2(root: root, path1: keyPath, path2: childKeyPath)
    }
}

public struct DirectChildChain2<Root: Reactable, Leaf: Reactable & ObservableEvent, T: Reactable & ObservableEvent> {
    weak var root: Root?
    let path1: KeyPath<Root.State, Leaf>
    let path2: KeyPath<Leaf.State, T>
    
    public init(root: Root?, path1: KeyPath<Root.State, Leaf>, path2: KeyPath<Leaf.State, T>) {
        self.root = root
        self.path1 = path1
        self.path2 = path2
    }
    
    public func observe() -> AnyPublisher<ObservableEventResult<T>, Never> {
        guard let root else { return Empty().eraseToAnyPublisher() }
        let leafPublisher = root.state
            .map { $0[keyPath: path1] }
            .prepend(root.currentState[keyPath: path1])
            .removeDuplicates(by: { ObjectIdentifier($0) == ObjectIdentifier($1) })
        
        return leafPublisher
            .map { leaf -> AnyPublisher<ObservableEventResult<T>, Never> in
                let childPublisher = leaf.state
                    .map { $0[keyPath: path2] }
                    .prepend(leaf.currentState[keyPath: path2])
                    .removeDuplicates(by: { ObjectIdentifier($0) == ObjectIdentifier($1) })
                
                return childPublisher
                    .map { child -> AnyPublisher<ObservableEventResult<T>, Never> in
                        child.observe().eraseToAnyPublisher()
                    }
                    .switchToLatest()
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
}

public struct ChildChain2Direct<Root: Reactable, Leaf: Reactable & ObservableEvent, T: Reactable & ObservableEvent> {
    weak var root: Root?
    let path1: KeyPath<Root.State, Leaf?>
    let path2: KeyPath<Leaf.State, T>
    
    public init(root: Root?, path1: KeyPath<Root.State, Leaf?>, path2: KeyPath<Leaf.State, T>) {
        self.root = root
        self.path1 = path1
        self.path2 = path2
    }
    
    public func observe() -> AnyPublisher<ObservableEventResult<T>, Never> {
        guard let root else { return Empty().eraseToAnyPublisher() }
        let leafPublisher = root.state
            .map { $0[keyPath: path1] }
            .prepend(root.currentState[keyPath: path1])
            .removeDuplicates(by: optionalIdentityEquals)
            .eraseToAnyPublisher()
        return observeNonOptionalDescendant(parentPublisher: leafPublisher, keyPath: path2)
    }
}

public struct ChildChain3Direct<Root: Reactable, Leaf: Reactable & ObservableEvent, T: Reactable & ObservableEvent, U: Reactable & ObservableEvent> {
    weak var root: Root?
    let path1: KeyPath<Root.State, Leaf?>
    let path2: KeyPath<Leaf.State, T?>
    let path3: KeyPath<T.State, U>
    
    public init(root: Root?, path1: KeyPath<Root.State, Leaf?>, path2: KeyPath<Leaf.State, T?>, path3: KeyPath<T.State, U>) {
        self.root = root
        self.path1 = path1
        self.path2 = path2
        self.path3 = path3
    }
    
    public func observe() -> AnyPublisher<ObservableEventResult<U>, Never> {
        guard let root else { return Empty().eraseToAnyPublisher() }
        let leafPublisher = root.state
            .map { $0[keyPath: path1] }
            .prepend(root.currentState[keyPath: path1])
            .removeDuplicates(by: optionalIdentityEquals)
            .eraseToAnyPublisher()
        let grandchildPublisher = chainOptionalChild(parentPublisher: leafPublisher, keyPath: path2)
        return observeNonOptionalDescendant(parentPublisher: grandchildPublisher, keyPath: path3)
    }
}

public struct ChildObserverChain<Root: Reactable, Leaf: Reactable & ObservableEvent> {
    weak var root: Root?
    let keyPath: KeyPath<Root.State, Leaf?>
    
    public init(root: Root?, keyPath: KeyPath<Root.State, Leaf?>) {
        self.root = root
        self.keyPath = keyPath
    }
    
    public func observe() -> AnyPublisher<ObservableEventResult<Leaf>, Never> {
        guard let root else { return Empty().eraseToAnyPublisher() }
        let leafPublisher = root.state
            .map { $0[keyPath: keyPath] }
            .prepend(root.currentState[keyPath: keyPath])
            .removeDuplicates(by: optionalIdentityEquals)
            .eraseToAnyPublisher()
        return observeOptionalLeaf(leafPublisher)
    }
    
    public func child<T: Reactable & ObservableEvent>(
        _ childKeyPath: KeyPath<Leaf.State, T>
    ) -> ChildChain2Direct<Root, Leaf, T> {
        ChildChain2Direct(root: root, path1: keyPath, path2: childKeyPath)
    }
    
    public func child<T: Reactable & ObservableEvent>(
        _ childKeyPath: KeyPath<Leaf.State, T?>
    ) -> ChildObserverChain2<Root, Leaf, T> {
        ChildObserverChain2(root: root, path1: keyPath, path2: childKeyPath)
    }
}

public struct ChildObserverChain2<Root: Reactable, Leaf: Reactable & ObservableEvent, T: Reactable & ObservableEvent> {
    weak var root: Root?
    let path1: KeyPath<Root.State, Leaf?>
    let path2: KeyPath<Leaf.State, T?>
    
    public init(root: Root?, path1: KeyPath<Root.State, Leaf?>, path2: KeyPath<Leaf.State, T?>) {
        self.root = root
        self.path1 = path1
        self.path2 = path2
    }
    
    public func observe() -> AnyPublisher<ObservableEventResult<T>, Never> {
        guard let root else { return Empty().eraseToAnyPublisher() }
        let leafPublisher = root.state
            .map { $0[keyPath: path1] }
            .prepend(root.currentState[keyPath: path1])
            .removeDuplicates(by: optionalIdentityEquals)
            .eraseToAnyPublisher()
        return observeOptionalLeaf(chainOptionalChild(parentPublisher: leafPublisher, keyPath: path2))
    }
    
    public func child<U: Reactable & ObservableEvent>(
        _ childKeyPath: KeyPath<T.State, U>
    ) -> ChildChain3Direct<Root, Leaf, T, U> {
        ChildChain3Direct(root: root, path1: path1, path2: path2, path3: childKeyPath)
    }
    
    public func child<U: Reactable & ObservableEvent>(
        _ childKeyPath: KeyPath<T.State, U?>
    ) -> ChildObserverChain3<Root, Leaf, T, U> {
        ChildObserverChain3(root: root, path1: path1, path2: path2, path3: childKeyPath)
    }
}

public struct ChildObserverChain3<Root: Reactable, Leaf: Reactable & ObservableEvent, T: Reactable & ObservableEvent, U: Reactable & ObservableEvent> {
    weak var root: Root?
    let path1: KeyPath<Root.State, Leaf?>
    let path2: KeyPath<Leaf.State, T?>
    let path3: KeyPath<T.State, U?>
    
    public init(root: Root?, path1: KeyPath<Root.State, Leaf?>, path2: KeyPath<Leaf.State, T?>, path3: KeyPath<T.State, U?>) {
        self.root = root
        self.path1 = path1
        self.path2 = path2
        self.path3 = path3
    }
    
    public func observe() -> AnyPublisher<ObservableEventResult<U>, Never> {
        guard let root else { return Empty().eraseToAnyPublisher() }
        let leafPublisher = root.state
            .map { $0[keyPath: path1] }
            .prepend(root.currentState[keyPath: path1])
            .removeDuplicates(by: optionalIdentityEquals)
            .eraseToAnyPublisher()
        let grandchildPublisher = chainOptionalChild(parentPublisher: leafPublisher, keyPath: path2)
        return observeOptionalLeaf(chainOptionalChild(parentPublisher: grandchildPublisher, keyPath: path3))
    }
}

public extension Reactable {
    /// Returns a chain to observe events from an optional child Reactable. Call `.observe()` to subscribe.
    func child<R: Reactable & ObservableEvent>(
        _ keyPath: KeyPath<State, R?>
    ) -> ChildObserverChain<Self, R> {
        ChildObserverChain(root: self, keyPath: keyPath)
    }
    
    /// Returns a chain to observe events from a non-optional child Reactable. Call `.observe()` to subscribe.
    func child<R: Reactable & ObservableEvent>(
        _ keyPath: KeyPath<State, R>
    ) -> DirectChildChain<Self, R> {
        DirectChildChain(root: self, keyPath: keyPath)
    }
}
