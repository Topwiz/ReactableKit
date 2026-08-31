# 🚀 ReactableKit

**[🇰🇷 한국어 ReadMe](README/README_ko.md)**

## 📌 Introduction

**ReactableKit** is a lightweight yet powerful state management framework for **SwiftUI** applications built on **Combine**.

Inspired by ReactorKit architecture, this framework provides a structured approach to efficiently handle business logic and state transformations.

## 📋 Requirements

- ✅ iOS 16.0+
- ✅ Swift 5+

## 📦 Installation

### Swift Package Manager (SPM)

You can easily install `ReactableKit` using Swift Package Manager. Open your project in Xcode, select `File` > `Add Packages...` from the menu, and enter the following URL:

```
https://github.com/topwiz/ReactableKit.git
```


Or add it directly to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/topwiz/ReactableKit.git", from: "version")
]
```

---

## 📚 Table of Contents

### ⚡ Basic Usage
- [1️⃣ Core Structure of Reactable](#1️⃣-core-structure-of-reactable)
- [2️⃣ Action Transformation with `transformAction`](#2️⃣-action-transformation-with-transformaction)
- [3️⃣ SwiftUI and Reactable](#3️⃣-swiftui-and-reactable)
- [4️⃣ `updateOn`: SwiftUI Update Optimization](#4️⃣-updateon-swiftui-update-optimization)
- [5️⃣ Action Dispatch](#5️⃣-action-dispatch)

### 🎨 Property Wrappers
- [`@ViewState`](#viewstate)
- [`@Shared`](#shared)
- [`@SharedViewState`](#sharedviewstate)
- [`@Emit` State Tracking](#emit-state-tracking)

### 🔬 Debugging
- [`ReactableInstrument` (Cycle Performance)](#-debugging--reactableinstrument)

### 🔧 Features
- [`ObservableEvent` (Parent-Child Communication)](#observableevent-parent-child-communication)
- [`ReactableView` Protocol](#reactableview-protocol)
- [`DependencyInjectable` & `Factory` Pattern](#dependencyinjectable--factory-pattern)

---

## ⚡ Basic Usage

### 1️⃣ Core Structure of Reactable

To use `Reactable`, create a class that conforms to the `Reactable` protocol. Define `Action`, `Mutation`, and `State`, then implement `mutate(action:)` and `reduce(state:mutation:)`.

```swift
final class CounterReactable: Reactable {
    enum Action: Sendable {
        case increase
        case decrease
        case loadData
    }
    
    struct State: Sendable {
        var count: Int = 0
        var isLoading: Bool = false
        var data: String = ""
        var errorMessage: String? = nil
    }
    
    enum Mutation: Sendable {
        case setCount(Int)
        case setLoading(Bool)
        case setData(String)
        case setError(String)
    }
    
    let initialState = State()
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .increase:
            return .just(.setCount(currentState.count + 1))
            
        case .decrease:
            return .run { send in 
                send(.setCount(self.currentState.count - 1))
            }
            
        case .loadData:
            return .run(priority: .userInitiated) { send in
                send(.setLoading(true))
                
                // Simulate async operation that can throw
                try await Task.sleep(nanoseconds: 1_000_000_000)
                let data = try await fetchDataFromAPI()
                
                send(.setData(data))
                send(.setLoading(false))
            } catch: { error, send in
                // Handle errors safely
                send(.setLoading(false))
                send(.setError(error.localizedDescription))
            }
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutate {
        case let .setCount(value):
            state.count = value
        case let .setLoading(isLoading):
            state.isLoading = isLoading
        case let .setData(data):
            state.data = data
        case let .setError(error):
            state.errorMessage = error
        }
    }
}
```

### 2️⃣ Action Transformation with `transformAction`

`transformAction` automatically enables **event-based action triggers**. This is useful for converting timers and various events into Reactable Actions.

```swift
func transformAction() -> AnyPublisher<Action, Never> {
    return Timer.publish(every: 5, on: .main, in: .common)
        .autoconnect()
        .map { _ in Action.autoIncrease }
        .eraseToAnyPublisher()
}
```

> ⚠️ **Important**: When not using `Store` and creating directly, make sure to call `initialize()` in the `init` method.

### 3️⃣ SwiftUI and Reactable

Use `Store` to detect state changes and dispatch `Action` in SwiftUI Views.

```swift
struct CounterView: View {
    @StateObject var store = Store { 
        CounterReactable()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("\(self.store.state.count)")
                .font(.largeTitle)
            
            Button("Increase") {
                self.store.action(.increase)
            }
        }
    }
}
```

### 4️⃣ `updateOn`: SwiftUI Update Optimization

You can reduce SwiftUI updates by monitoring only specific states:

```swift
struct OptimizedView: View {
    @ObservedObject var store = Store { CounterReactable() }

    var body: some View {
        VStack {
            // ✅ Updates only when `count` changes
            self.store.updateOn(\.count) { value in
                Text("\(value)")
                    .font(.headline)
            }
            
            // ✅ Using with action
            self.store.updateOn(\.isOn) { value in
                Toggle(isOn: value) {
                    Text("Toggle")
                }
            } action: { newValue in
                .toggleChanged
            }
            
            // ✅ ForEach example
            ForEach(self.store.state.items) { item in
                self.store.updateOn(\.items, for: item.id) { value in
                    Text("\(value.name)")
                }
            }
            
            // ✅ ForEach List multiple views example
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

### 5️⃣ Action Dispatch

#### Normal Action
```swift
store.action(.increase)
```

#### Concurrency Action

You can receive the final state after the action is completely processed and the state is updated.

```swift
let finalState = await store.asyncAction(.increase)
print("Final count: \(finalState.count)")
```

---

## 🎨 Property Wrappers

### `@ViewState`
`@ViewState` ensures **automatic UI updates** when values change. Properties without `@ViewState` do not trigger SwiftUI updates.

```swift
struct State {
    @ViewState var count: Int = 1
    /// When ignoreEquality = true, SwiftUI View updates even when the same value is set
    @ViewState(ignoreEquality: true) var forceUpdate: Bool = false
    /// animation: When animation is set, animation is applied when the value changes
    @ViewState(animation: .default) var animatedValue: Double = 0.0
}
```

### `@Shared`

`@Shared` enables **state sharing between parent and child components**.

```swift
/// `file` and `UserDefaults` storage must conform to Codable
struct SharedState: Codable, Equatable {
    var username: String = ""
    var age: Int = 0
    var isPremium: Bool = false
}

struct State {
    @Shared(.file()) var sharedState = SharedState()
    @Shared(.file(path: "Test/")) var sharedState = SharedState() // Subfolder path
    @Shared var sharedState = SharedState()
    @Shared(key: "custom_key") var sharedState = SharedState() // Custom key
    @ViewState var displayInfo: String = ""
}
```

> ⚠️ `@Shared` does not automatically update the UI when values change.

### `@SharedViewState`

`@SharedViewState` combines the sharing capabilities of `@Shared` with the automatic UI updating of `@ViewState`. It manages shared state values that trigger SwiftUI updates when changed.

```swift
struct State {
    @SharedViewState var sharedCount: Int = 0
    /// When ignoreEquality = true, SwiftUI View updates even when the same value is set
    @SharedViewState(ignoreEquality: true) var forceSharedUpdate: Bool = false
    /// animation: When animation is set, animation is applied when the value changes
    @SharedViewState(animation: .default) var animatedSharedValue: Double = 0.0
}
```

> ⚠️ **Warning**: Setting `ignoreEquality` to `true` may cause unnecessary updates to the SwiftUI view.

### `@Emit` State Tracking

`@Emit` triggers updates even when the same value is set.

```swift
struct State {
    @Emit var title: String = "Hello"
}
```

#### Subscribing to `emit(_:)`

```swift
reactable.emit(\.$title)
    .sink { newValue in
        print("Title changed:", newValue)
    }
    .store(in: &cancellables)
```

#### Using `@Emit` in SwiftUI

```swift
ZStack { }
.emit(\.$title, from: self.store) { value in
    print("Title updated:", value)
}
```

---

## 🔧 Features

### `ObservableEvent` (Parent-Child Communication)

`ObservableEvent` enables **action transmission between child and parent components**.

#### Basic: Static `observe()` and Instance `observe()`

```swift
// Child Reactable
class ChildReactable: Reactable, ObservableEvent {
    enum Action {
        case notifyParent(Int)
    }
}

// Parent Reactable - observe all instances (global)
func transformAction() -> AnyPublisher<Action, Never> {
    let childEvent = ChildReactable.observe()
        .filter { result in
            if case .notifyParent = result.action { return true }
            return false
        }
        .map(Action.parentAction)
        .eraseToAnyPublisher()

    // Observe specific instance (when child is always in state)
    let localChildEvent = self.currentState.childReactable.observe()
        .filter { result in
            if case .notifyParent = result.action { return true }
            return false
        }
        .map(Action.parentAction)
        .eraseToAnyPublisher()

    return .merge([childEvent, localChildEvent])
}
```

#### Recommended: `child` (Scoped to Your Child)

When the same child type is used by multiple parents, `ChildType.observe()` delivers events to **all** parents. Use `child` to receive only events from **your** child instance. **Always call `.observe()`** to subscribe:

```swift
// Parent State - child can be non-optional or optional
struct State {
    var childReactable: ChildReactable           // non-optional
    var optionalChild: ChildReactable?           // optional (e.g. lazy-loaded)
}

// Parent transformAction
func transformAction() -> AnyPublisher<Action, Never> {
    // Non-optional: call .observe() to subscribe
    let childEvents = self.child(\.childReactable)
        .observe()
        .filter { result in
            if case .notifyParent = result.action { return true }
            return false
        }
        .map(Action.parentAction)
        .eraseToAnyPublisher()

    // Optional: same pattern – call .observe() to subscribe
    let optionalChildEvents = self.child(\.optionalChild)
        .observe()
        .filter { result in
            if case .notifyParent = result.action { return true }
            return false
        }
        .map(Action.parentAction)
        .eraseToAnyPublisher()

    return .merge([childEvents, optionalChildEvents])
}
```

**`child` benefits:**
- **Unified API**: Both optional and non-optional require `.observe()` – no confusion about when to call it
- **Filters by `sourceId`**: Only your child's events are delivered
- **No wrong-parent routing**: When multiple parents share the same child type, each parent receives only its own child's events

#### Chained `child` (Nested Optional Children)

When you have nested optional children (e.g. `parent → optionalChild? → optionalGrandchild?`), chain `child` calls and call `.observe()` at the end:

```swift
// 2-level chain (optional → optional)
self.child(\.fullRouteReactable)
    .child(\.routeDetailReactable)
    .observe()
    .sink { result in ... }
    .store(in: &cancellables)

// optional → non-optional grandchild
self.child(\.optionalChild)
    .child(\.grandchild)
    .observe()
    .sink { ... }
    .store(in: &cancellables)

// Single-level optional
self.child(\.optionalChild).observe().sink { ... }
```

#### `ObservableEventResult`

```swift
public struct ObservableEventResult<R: Reactable> {
    public let action: R.Action
    public var state: R.State
    /// Identifies the Reactable instance that sent this event (for `child` filtering)
    public let sourceId: ObjectIdentifier
}
```

### `ReactableView` Protocol

Use the `ReactableView` protocol that follows @MainActor in UIKit views.

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

### `DependencyInjectable` & `Factory` Pattern

Combines dependency injection system with factory pattern to simplify object creation and dependency management in real, preview, and test environments.

#### 1. DependencyInjectable

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

// If the dependency itself is @MainActor-isolated, declare the conformance as isolated.
// The protocol stays the same — only the conformance carries the isolation:
//
//     extension Service: @MainActor DependencyInjectable {
//         static var real: ServiceProtocol { Service.shared }
//     }
//     extension GlobalDependencyKey {
//         @MainActor var service: ServiceProtocol { self[Service.self] }
//     }

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
@Dependency(\.service) var service: ServiceProtocol
```

> **Thread-safety note.** `@Dependency` resolves lazily on first access and caches the result
> behind a lock, so it is safe to hold in an `actor`, a `Sendable` class, or a plain struct.
> The value's own isolation still governs how you may use it: a `@MainActor`-isolated dependency
> stays main-actor-only. Note that the compiler does **not** flag a `Sendable` type holding a
> non-Sendable dependency through `@Dependency` — macro-generated storage escapes that check —
> so make the dependency `Sendable` yourself when it crosses isolation boundaries.


#### 2. Factory

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

#### 3. AnyFactory

`AnyFactory` is a generic wrapper that abstracts the object creation process.
It creates objects using Factory and transforms them into the desired output type through transformation closures.

```swift
extension MyFactory: DependencyInjectable {
    typealias DependencyType = AnyFactory<`ProtocolType`, Payload>
    
    static var real: DependencyType {
        AnyFactory(factory: MyFactory.Factory())
    }
    
    static var test: DependencyType {
        AnyFactory(factory: MockFactory.Factory())
    }
}
```

## 🔬 Debugging — `ReactableInstrument`

`ReactableInstrument` measures every stage of the Reactable cycle and warns when one of them takes
too long. It exists only in **DEBUG** builds — the file and every call site inside `Reactable` are
removed by `#if DEBUG`, so a release build carries none of it.

```
action(_:) ─▶ [Queue] ─▶ [Mutate] ─▶ [Effect] ─▶ [Reduce] ─▶ state
```

| Stage | What it measures |
|---|---|
| `Queue` | How long the action waited on the main queue before `mutate` ran |
| `Mutate` | Synchronous cost of building the mutation publisher |
| `Effect` | Lifetime of that publisher, from subscription to completion |
| `Reduce` | Synchronous cost of applying a mutation to the state |

`Queue` is the one to watch for a stalled UI: every individual stage can look healthy while actions
pile up behind a blocked main queue, and only queue latency shows that.

### Turning it on

Instrumentation is opt-in. Override `instrumentation` on the Reactable you care about:

```swift
#if DEBUG
extension MyHighFrequencyReactable {
    var instrumentation: ReactableInstrument.Options? { .default }
}
#endif
```

`Options` takes a `label` to tell several instances of the same type apart, and a
`warningThreshold` to override the global one for this Reactable:

```swift
var instrumentation: ReactableInstrument.Options? {
    .init(label: "carplay", warningThreshold: 0.016)   // one frame at 60fps
}
```

To measure everything without touching any code, set `REACTABLE_INSTRUMENT` to `1` in the scheme's
environment variables, or flip it at runtime from a debug menu:

```swift
ReactableInstrument.enabledByDefault = true
ReactableInstrument.filter = { $0.contains("Guide") }   // by Reactable type name
```

Precedence: a Reactable's own `instrumentation` always wins. Otherwise, when a `filter` is set it
decides on its own — a non-matching type name stays un-instrumented even with `enabledByDefault` or
`REACTABLE_INSTRUMENT` on, so a filter narrows a global switch rather than widening it.

### Warnings

Anything at or above the threshold (50 ms by default) is logged:

```
Slow reduce: playground.MyReactable updateLocation took 200.3ms (threshold 50.0ms)
```

Warnings are rate limited to one per reactable/stage/case per `warningInterval` (1 s by default), so
a high-frequency stream cannot flood the log. Statistics still record every sample.

`Effect` is measured upstream of `reduce`, and Combine delivers a value synchronously through
`reduce` before the completion event arrives — so a slow `reduce` inflates the `Effect` sample as
well. When `Slow effect` and `Slow reduce` name the same action, the reduce is the cause; the effect
is not doing async work.

### Aggregated report

```swift
print(ReactableInstrument.report())
```

```
ReactableInstrument report (threshold 50.0ms)
REACTABLE    STAGE   CASE                COUNT        P50        P90        MAX
MyReactable  queue   updateLocation        412      0.8ms     12.0ms    137.4ms
MyReactable  reduce  setLocation           412      0.1ms      0.2ms      4.1ms
```

### Observing every measurement

```swift
ReactableInstrument.onEvent = { event in
    // event.stage, event.reactable, event.name, event.duration
}
```

Do not dispatch an action into an instrumented Reactable from this hook — the resulting cycle would
emit more events, forever.

### Instruments

Edit Scheme ▸ Profile ▸ Build Configuration = **Debug**, then ⌘I, add the **os_signpost**
instrument, and look for subsystem `ReactableInstrument.subsystem` (the app's bundle identifier by
default) / category `Reactable`.

### Try it

The sample app has a playground screen — `📈 ReactableInstrument Playground` in
`Example/SampleProject` — with sliders for the threshold and the per-action cost, buttons that make
each stage slow on purpose, and a burst/flood stress test that reproduces a main-queue backlog.

## 🏗️ Roadmap

- [ ] 💻 Mac Support
- [ ] 🚀 Performance Optimizations

## 🔗 References

- [ReactorKit](https://github.com/ReactorKit/ReactorKit)
- [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture)

## 📜 License

**ReactableKit** is available under the MIT license.
