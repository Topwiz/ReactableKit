# 🚀 ReactableKit

## 📌 Introduction

**ReactableKit** is a lightweight yet powerful **state management** framework designed for **SwiftUI** applications. Inspired by **ReactorKit**, it provides a structured approach to handling **business logic** and **state transformations** efficiently.

## 📋 Requirements

- ✅ iOS 15.0+
- ✅ Swift 5+

---

## ⚡ Usage

### 1️⃣ Core Structure of Reactable

To use `Reactable`, create a class conforming to the `Reactable` protocol. Define `Action`, `State`, and `Mutation`, and implement `mutate(action:)` and `reduce(state:mutate:)`.

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

### 2️⃣ Transforming Actions with `transformAction`

`transformAction` enables automatic **event-based action triggers**. This is useful for handling timers, network events, or external input sources.

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

### 3️⃣ Integrating Reactable with SwiftUI

Utilize `Store` to observe state changes and dispatch `Action` within a SwiftUI view.

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

### 4️⃣ Dispatching Actions in Reactable

Reactable provides multiple ways to **send actions and track completion**.

```swift
// Using async-await
Task {
    let state = try await CounterReactable().action(.increase)
}

// Using Combine’s sink
let action = CounterReactable().actionPublish(.increase)
    .sink { state in
        print(state)
    }

// Using Completion Handler
CounterReactable().action(.increase) { result in
    print(result)
}
```

---

## 🎯 Advanced Features

### 1️⃣ Property Wrappers

#### 🎨 `@ViewState`

`@ViewState` ensures **automatic UI updates** when values change. Properties without `@ViewState` will not trigger UI updates.

```swift
struct State {
    @ViewState var count: Int = 1
    @ViewState(disableCheckingEquatable: true) var forceUpdate: Bool = false
}
```

#### 🔄 `@Shared`

`@Shared` enables **state sharing** between **parent and child components**.

```swift
struct SharedState: Codable, Equatable, Hashable {
    var username: String = ""
    var age: Int = 0
    var isPremium: Bool = false
}

struct State {
    @Shared(.memory) var sharedState = SharedState()
    @ViewState var displayInfo: String = ""
}
```

> ⚠️ `@Shared` does not automatically update the UI when values change.

#### 📦 Using `@Emit` for State Tracking
`@Emit` ensures that **even if the value is set to the same value, it will still trigger updates**.

#### 📌 Using `@Emit` in State

```swift
struct MyState {
    @Emit var title: String = "Hello"
}
```

#### 📌 Subscribing to `emit(_:)`

```swift
reactable.emit(\ .$title)
    .sink { newValue in
        print("Title updated:", newValue)
    }
    .store(in: &cancellables)
```



### 2️⃣ `ObservableEvent` (Child → Parent Communication)

`ObservableEvent` enables **child components to send actions to parent components**.

```swift
// Child Reactable
class ChildReactable: Reactable, ObservableEvent { 
    enum Action {
        case notifyParent(Int)
    }
}

// Parent Reactable
func transformAction() -> AnyPublisher<Action, Never> {
    let childEvent = ChildReactable.observe() // observe's ChildReactable Action and changed State
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

---

## 🏗️ Roadmap
- [ ] ✅ Unit Testing
- [ ] 🚀 Performance Optimizations
- [ ] 📖 Additional Documentation & Examples

## 🔗 References

- [ReactorKit](https://github.com/ReactorKit/ReactorKit)
- [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture)

## 📜 License

**ReactableKit** is available under the MIT license.
