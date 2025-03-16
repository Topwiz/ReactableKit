# 🚀 ReactableKit

## Table of Contents
  - [⚡ Basic Usage](#-basic-usage)
    - [1️⃣ Core Structure of Reactable](#1️⃣-core-structure-of-reactable)
    - [2️⃣ Action Transformation with transformAction](#2️⃣-action-transformation-with-transformaction)
    - [3️⃣ Integrating Reactable with SwiftUI](#3️⃣-integrating-reactable-with-swiftui)
    - [4️⃣ updateOn: Optimizing SwiftUI Updates](#4️⃣-updateon-optimizing-swiftui-updates)
    - [5️⃣ Dispatching Actions in Reactable](#5️⃣-dispatching-actions-in-reactable)
- [1️⃣ Property Wrappers](#1️⃣-property-wrappers)
    - [🎨 `@ViewState`](#-viewstate)
    - [🔄 `@Shared`](#-shared)
    - [📦 Using `@Emit` for State Tracking](#-using-emit-for-state-tracking)
      - [📌 Using `@Emit` in Your State](#-using-emit-in-your-state)
      - [📌 Subscribing to emit(\_:)](#-subscribing-to-emit_)
      - [📌 Using `@Emit` in SwiftUI](#-using-emit-in-swiftui)
- [2️⃣ `ObservableEvent` (Parent-Child Communication)](#2️⃣-observableevent-parent-child-communication)
- [3️⃣ `ReactableView` Protocol](#3️⃣-reactableview-protocol)
- [4️⃣ `DependencyInjection` and `Factory` Pattern Usage](#4️⃣-dependencyinjection-and-factory-pattern-usage)
    - [1. DependencyInjectable](#1-dependencyinjectable)
    - [2. Factory](#2-factory)
    - [3. AnyFactory](#3-anyfactory)

## ⚡ Basic Usage

### 1️⃣ Core Structure of Reactable

To use `Reactable`, you must create a class that conforms to the `Reactable` protocol. Define `Action`, `Mutation`, and `State`, and then implement `mutate(action:)` and `reduce(state:mutate:)`.

```swift
final class CounterReactable: Reactable {
    
    enum Action {
        case increase
        case decrease
    }
    
    struct State {
        var count: Int = 0
    }
    
    enum Mutation {
        case setCount(Int)
    }
    
    var initialState = State()
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .increase:
            return .just(.setCount(self.currentState.count + 1))
        case .decrease:
            return .just(.setCount(self.currentState.count - 1))
        }
    }
    
    func reduce(state: inout State, mutate: Mutation) {
        switch mutate {
        case let .setCount(value):
            state.count = value
        }
    }
}
```

### 2️⃣ Action Transformation with transformAction

`transformAction` automatically enables **event-driven action triggers**. This is useful for converting timers or other triggers into Reactable Actions.

```swift
final class CounterReactable: Reactable {
    
    enum Action {
        case increase
        case autoIncrease
    }
    
    struct State {
        var count: Int = 0
    }
    
    enum Mutation {
        case setCount(Int)
    }
    
    var initialState = State()
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .increase:
            return .just(.setCount(self.currentState.count + 1))
        case .autoIncrease:
            return .just(.setCount(self.currentState.count + 2))
        }
    }
    
    func reduce(state: inout State, mutate: Mutation) {
        switch mutate {
        case let .setCount(value):
            state.count = value
        }
    }
    
    func transformAction() -> AnyPublisher<Action, Never> {
        return .merge([
            Timer.publish(every: 5, on: .main, in: .common)
                .autoconnect()
                .map { _ in Action.autoIncrease }
                .eraseToAnyPublisher()
        ])
    }
}
```
> ⚠️ If you are not using `Store`, you must manually call `registerTransform()` in the Reactable `init`.

### 3️⃣ Integrating Reactable with SwiftUI

Use `Store` to observe state changes and dispatch `Action` in a SwiftUI View.

```swift
struct CounterView: View {
    @StateObject var store = Store { 
        CounterReactable()
    }
    
    var body: some View {
        VStack {
            Text("\(store.state.count)")
                .font(.largeTitle)
                .padding()
            
            Button("Increase") {
                store.action(.increase)
            }
        }
    }
}
```

### 4️⃣ updateOn: Optimizing SwiftUI Updates

`updateOn` is a SwiftUI state observer that ensures views update only when necessary.

```swift
struct CounterView: View {
    @ObservedObject var store = Store { 
        CounterReactable() 
    }

    var body: some View {
        VStack(spacing: 20) {
            // ✅ The UI only updates when `count` changes. It does not update when `count1` changes.
            
            self.store.updateOn(\.count) { value in
                Text("\(value)")
                    .font(.headline)
            }

            // Always updates
            Text("\(self.store.state.count1)")
                .font(.headline)

            // Binding<Value> example
            self.store.updateOn(\.isOn1) { value in
                Toggle(isOn: value) {
                    Text("Toggle 1")
                }
            }

            // Binding<Value> example with action
            self.store.updateOn(\.isOn1) { value in
                Toggle(isOn: value) {
                    Text("Toggle 1 updateOn with action")
                }
            } action: { newValue in
                .isOnChanged
            }
            
            // ForEach list example
            ForEach(self.store.state.list) { item in
                self.store.updateOn(\.list, for: item.id) { value in
                    Text("\(value.index)")
                        .font(.headline)
                }
            }
            
            // ForEach multiple views example
            ForEach(self.store.state.list) { item in
                HStack {
                    self.store.updateOn(\.list, for: item.id, property: \.index) { value in
                        Text("\(value)")
                            .font(.headline)
                    }
                    
                    self.store.updateOn(\.list, for: item.id, property: \.toggle) { value in
                        Toggle(isOn: value) {
                            Text("Toggle 2 updateOn")
                        }
                    }
                }
            }
        }
    }
}
```

### 5️⃣ Dispatching Actions in Reactable

Reactable provides various ways to **send actions and track completion**.

```swift
// async-await example
let reactable = CounterReactable()
Task {
    let state = try await reactable.action(.increase)
}

// Combine sink example
let action = reactable.actionPublish(.increase)
    .sink { state in
        print(state)
    }

// Completion handler example
reactable.action(.increase) { result in
    print(result)
}
```

## 🎯 Advanced Features

### 1️⃣ Property Wrappers

#### 🎨 `@ViewState`

`@ViewState` guarantees **automatic UI updates** when values change. Properties not marked with `@ViewState` will not trigger SwiftUI updates.

```swift
struct State {
    @ViewState var count: Int = 1
    /// If ignoreEquality = true, SwiftUI views update even if the same value is set.
    @ViewState(ignoreEquality: true) var forceUpdate: Bool = false
}
```

#### 🔄 `@Shared`

`@Shared` allows **shared state** between parent and child components.

```swift
/// The file or UserDefaults storage must conform to Codable.
struct SharedState: Codable, Equatable {
    var username: String = ""
    var age: Int = 0
    var isPremium: Bool = false
}

struct State {
    @Shared(.file()) var sharedState = SharedState()
    @Shared(.file(path: "Test/")) var sharedState = SharedState() // subfolder path
    @Shared var sharedState = SharedState()
    @Shared(key: "custom_key") var sharedState = SharedState() // custom key
    @ViewState var displayInfo: String = ""
}
```

> ⚠️ Even if `@Shared` values change, the UI will not automatically update.

#### 📦 Using `@Emit` for State Tracking

`@Emit` triggers updates even when the same value is set repeatedly.

#### 📌 Using `@Emit` in Your State

```swift
struct MyState {
    @Emit var title: String = "Hello"
}
```

#### 📌 Subscribing to emit(_:)

```swift
reactable.emit(\.$title)
    .sink { newValue in
        print("Title updated:", newValue)
    }
    .store(in: &cancellables)
```

#### 📌 Using `@Emit` in SwiftUI

```swift
ZStack { }
.emit(\.$title, from: self.store) { value in
    print("Title updated:", value)
}
```

### 2️⃣ `ObservableEvent` (Parent-Child Communication)

`ObservableEvent` lets you send actions between child and parent components.

```swift
// Child Reactable
class ChildReactable: Reactable, ObservableEvent { 
    enum Action {
        case notifyParent(Int)
    }
}

// Parent Reactable
func transformAction() -> AnyPublisher<Action, Never> {
    let childEvent = ChildReactable.observe() // Observe actions and updates from ChildReactable
        .filter { result in
            if case .notifyParent = result.action { return true }
            return false
        }
        .map(Action.parentAction)
        .eraseToAnyPublisher()
    
    return .merge([
        childEvent,
    ])
}
```

### 3️⃣ `ReactableView` Protocol

Use the `ReactableView` protocol in UIKit views.

```swift
final class UIKitView: UIView {
    var cancellables: Set<AnyCancellable> = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.reactable = .init()
    }
}

extension UIKitView: ReactableView { 
    // Called when self.reactable is set
    func bind(reactable: UIKitReactable) { 

    }
}
```

## 4️⃣ `DependencyInjection` and `Factory` Pattern Usage

Combine the dependency injection system with factory patterns to simplify object creation and dependency management in real, preview, and test environments.

### 1. DependencyInjectable

The `DependencyInjectable` protocol allows types to define dependencies for different environments.

```swift
public protocol DependencyInjectable {
    associatedtype DependencyType
    static var real: DependencyType { get }
    static var preview: DependencyType { get } // optional
    static var test: DependencyType { get } // optional
}
```

#### Example:

```swift
protocol ServiceProtocol {
    func test() -> String
}

struct Service: ServiceProtocol {
    func test() -> String { "real" }
    
    struct Mock: ServiceProtocol {
        public init() {}
        public func test() -> String { "mock" }
    }
    
    struct TestMock: ServiceProtocol {
        public init() {}
        public func test() -> String { "test" }
    }
}

extension Service: DependencyInjectable {
    static var real: ServiceProtocol { Service() }
    static var preview: ServiceProtocol { Service.Mock() }
    static var test: ServiceProtocol { Service.TestMock() }
}

extension GlobalDependencyKey {
    var service: ServiceProtocol {
        self[Service.self]
    }
}

// usage
@Dependency(\.service) var service
```

### 2. Factory

```swift
final class TestObject: Factory {
    struct Payload {
        var text: String
    }

    let payload: Payload
    
    init(payload: Payload) {
        self.payload = payload
    }
    
    func print1() {
        print(self.payload.text)
    }
}

extension TestObject: DependencyInjectable {
    typealias DependencyType = TestObject.Factory
    static var real: TestObject.Factory { .init() }
}

extension GlobalDependencyKey {
    var testObjectFactory: TestObject.Factory {
        self[TestObject.self]
    }
}

// usage
@Dependency(\.testObjectFactory) var testObjectFactory
```

### 3. AnyFactory

`AnyFactory` is a generic wrapper that abstracts the object creation process.
After creating the object via a factory, you can convert it to your desired output type using a transform closure.

```swift
// Define a protocol for testing
protocol FactoryTestProtocol {
    func test() -> String
}

// Real factory implementation
struct FactoryTest: FactoryTestProtocol, Factory {
    struct Payload { }
    let payload: Payload
    
    init(payload: Payload) {
        self.payload = payload
    }
    
    func test() -> String { "real \(payload)" }
}

// Mock factory implementation
struct FactoryTestMock: FactoryTestProtocol, Factory {
    let payload: FactoryTest.Payload
    
    init(payload: FactoryTest.Payload) {
        self.payload = payload
    }
    
    func test() -> String { "mock \(payload)" }
}

// Conform FactoryTest to DependencyInjectable using AnyFactory
extension FactoryTest: DependencyInjectable {
    typealias DependencyType = AnyFactory<FactoryTestProtocol, Payload>
    
    static var real: DependencyType {
        DependencyType(factory: FactoryTest.Factory())
    }
    static var test: DependencyType {
        DependencyType(factory: FactoryTestMock.Factory())
    }
}

extension GlobalDependencyKey {
    var factoryTestFactory: FactoryTest.DependencyType {
        self[FactoryTest.self]
    }
}
```
