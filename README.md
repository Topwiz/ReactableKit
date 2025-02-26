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

### 4️⃣ `updateOn`: Optimizing SwiftUI Updates
`updateOn` is a powerful SwiftUI state observer that ensures views update only when necessary. It automatically detects whether the keyPath is a Value or Binding<Value> and prevents unnecessary UI re-renders.

#### Using updateOn for Value-Based State Updates
When using a normal value (Int, Bool, etc.), updateOn ensures the view only updates when the value changes.
- Ensures minimal SwiftUI re-renders
- Uses EquatableValueView for optimal performance

```swift
struct CounterView: View {
    @ObservedObject var store = Store { 
        CounterReactable() 
    }

    var body: some View {
        VStack(spacing: 20) {
            // ✅ updates UI when `count` changes. It does not update when count1 changes.
            
            self.store.updateOn(\.count) { value in
                Text("\(value)")
                    .font(.headline)
            }

           // Always updates
           
            Text("\(self.store.state.count1)")
                .font(.headline)

           // Binding<Value> Exmaple
           
           self.store.updateOn(\.isOn1) { value in
                Toggle(isOn: value) {
                    Text("Toggle 1")
                }
            }

            // Binding<Value> With Action Exmaple 
            
            self.store.updateOn(\.isOn1) { value in
                Toggle(isOn: value) {
                    Text("Toggle 1 updateOn with action")
                }
            } action: { newValue in
                .isOnChanged
            }
            
            // ForEach List Example
            
            ForEach(self.store.state.list) { item in
                self.store.updateOn(\.list, for: item.id) { value in
                    Text("\(value.index)")
                        .font(.headline)
                }
            }
            
            // ForEach List Multi View Example
            
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

Reactable provides multiple ways to **send actions and track completion**.

```swift
// Using async-await
let reactable = CounterReactable()
Task {
    let state = try await reactable.action(.increase)
}

// Using Combine’s sink
let action = reactable.actionPublish(.increase)
    .sink { state in
        print(state)
    }

// Using Completion Handler
reactable.action(.increase) { result in
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
    @ViewState(ignoreEquality: true) var forceUpdate: Bool = false
}
```

#### 🔄 `@Shared`

`@Shared` enables **state sharing** between **parent and child components**.

```swift
struct SharedState: Codable, Equatable {
    var username: String = ""
    var age: Int = 0
    var isPremium: Bool = false
}

struct State {
    @Shared(.file()) var sharedState = SharedState()
    @Shared(.file(path: "Test/")) var sharedState = SharedState() // sub folder path
    @Shared var sharedState = SharedState()
    @Shared(key: "custom_key") var sharedState = SharedState() // custom key
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

### 3️⃣`ReactableView` Protocol
Use `ReactableView` Protocol on UIKit Views.

```swift
final class UIKitView: UIView {
    var cancellables: Set<AnyCancellable> = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.reactable = .init()
    }
}

extension UIKitView: ReactableView { 
    // Call's when self.reactable is set.
    func bind(reactable: UIKitReactable) { 

    }
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
