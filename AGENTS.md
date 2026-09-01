# Writing ReactableKit & DependencyInjectableKit Code

A rulebook for AI coding agents (and humans) working in a codebase that uses these
two libraries. Every rule below is stated as **Do this / Never do this** with the
reason attached, because the reason is what tells you when the rule stops applying.

Assumed baseline: Swift 6 language mode, iOS 16+.

---

## 0. The three facts everything else follows from

1. **`Reactable` is not actor-isolated, but every operation runs on the main
   thread.** State reads and writes hop through `DispatchQueue.main`, and `.run`
   bodies execute inside `Task { @MainActor in }`. The contract is enforced at
   runtime, not by the type system, so you do not hop to the main actor to talk
   to a Reactable — and you do not annotate one either.
2. **State flows one way.** `action` → `mutate` → `Mutation` → `reduce` → `State`.
   Nothing else may write state.
3. **`@Dependency` is an attached macro and a property wrapper sharing one
   name.** The macro takes member declarations, the wrapper takes local ones.
   Both own a storage that resolves lazily behind its own lock, so the two
   behave identically — it works in any type (a `Reactable`, an `actor`, a
   `Sendable` class, a plain struct) and in any local scope.

---

## 1. Declaring a Reactable

### ✅ Do

```swift
final class CounterReactable: Reactable {
    enum Action {
        case increase
        case decrease
    }

    enum Mutation {
        case setCount(Int)
    }

    struct State {
        @ViewState var count: Int = 0
    }

    let initialState = State()

    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .increase:
            return .just(.setCount(self.currentState.count + 1))
        case .decrease:
            return .just(.setCount(self.currentState.count - 1))
        }
    }

    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .setCount(value):
            state.count = value
        }
    }
}
```

`Action`, `Mutation` and `State` must be `Sendable`. Enums of `Sendable` payloads
and structs of `Sendable` properties get it for free — you rarely write the
conformance yourself.

### ⚠️ Know when `@unchecked Sendable` is actually required

`Reactable` itself does not require `Sendable`, so a plain Reactable needs no
annotation. Two things pull `Sendable` in:

- adopting `PathState` for navigation
- a `State` that holds a child Reactable

Once the class must be `Sendable`, a mutable stored property — `var initialState`
being the usual one — makes the checked conformance fail with *"stored property
'initialState' of 'Sendable'-conforming class is mutable"*. `@unchecked Sendable`
is the escape hatch there:

```swift
final class CounterReactable: Reactable, PathState, @unchecked Sendable {
    var initialState = State()
}
```

Prefer `let initialState` when you can — then the checked conformance holds and
the annotation is unnecessary. Reach for `@unchecked` only for this specific
shape, never to silence an unrelated concurrency error.

### ❌ Never: add `@MainActor` to your Reactable

```swift
// WRONG — the protocol is not isolated, so this makes the conformance cross
// an isolation boundary
@MainActor
final class CounterReactable: Reactable { }
```

The compiler rejects it: *"conformance of 'CounterReactable' to protocol
'Reactable' crosses into main actor-isolated code and can cause data races"*.
Main-thread execution is already guaranteed at runtime; leave the class
nonisolated. Same for members in a `Reactable` extension.

### ❌ Never: mutate state outside `reduce`

```swift
// WRONG
func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
    self.currentState.count += 1        // bypasses the pipeline
    return .empty()
}
```

`reduce` is the only writer. `mutate` reads `currentState` and emits mutations.
Writing elsewhere desynchronises the replayed state from the view.

### ❌ Never: do work in `reduce`

```swift
// WRONG
func reduce(state: inout State, mutation: Mutation) {
    state.items = self.repository.fetchAll()   // I/O in a pure function
}
```

`reduce` must be pure and synchronous: mutation in, state out. Side effects,
async work and I/O belong in `mutate`.

---

## 2. Async work

### ✅ Do: use `.run` for anything asynchronous

```swift
func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
    switch action {
    case .load:
        return .run { send in
            let items = try await self.repository.fetch()
            send(.setItems(items))
        } catch: { error, send in
            send(.setError(error.localizedDescription))
        }
    }
}
```

`.run` already runs its body on the main actor (`Task { @MainActor in }` inside),
so you can touch `self`, `currentState` and child Reactables directly. It emits
zero or more values through `send` and cancels with the subscription.

### ❌ Never: wrap Reactable calls in `Task { }`

```swift
// WRONG
func reduce(state: inout State, mutation: Mutation) {
    Task { @MainActor in
        state.child.action(.refresh)     // also: captures inout state
    }
}

// RIGHT — same isolation domain, call it directly
func reduce(state: inout State, mutation: Mutation) {
    state.child.action(.refresh)
}
```

Everything in a Reactable is already on the main actor. A `Task` here buys you
nothing, reorders the work, and breaks the ordering guarantees the pipeline gives
you.

### ❌ Never: use a detached `Task` to escape isolation

```swift
// WRONG
Task.detached { self.reactable.action(.tick) }
```

If you genuinely start on a background thread, send the action through
`await store.action(_:)` or hop with `await MainActor.run { }` — but first check
whether the work needs to be off-main at all.

### ✅ Do: use `asyncAction` when you need the resulting state

```swift
let newState = await reactable.asyncAction(.save)
```

It suspends until the mutation pipeline for that action completes and returns the
state at that point. Useful in tests and in sequential flows.

---

## 3. State, views and re-rendering

### ✅ Do: mark view-facing properties `@ViewState` and read them with `updateOn`

```swift
struct State {
    @ViewState var count: Int = 0
    @ViewState var title: String = ""
}
```

```swift
struct CounterView: View {
    @ObservedObject var store: Store<CounterReactable>

    var body: some View {
        VStack {
            store.updateOn(\.count) { count in
                Text("\(count)")
            }
            Button("+") { store.action(.increase) }
        }
    }
}
```

`updateOn` scopes invalidation to one property, so changing `title` does not
re-render the `count` subtree.

### ❌ Never: expect a plain `var` in State to update the view

```swift
struct State {
    var count: Int = 0        // WRONG if a view reads it — nothing re-renders
}
```

`Store` drives `objectWillChange` only from `@ViewState` and `@SharedViewState`
properties, which it discovers by reflecting over State at init. A plain stored
property changes silently: the value is correct, the screen is stale. Both
wrappers require `Value: Equatable & Sendable`.

### ❌ Never: read whole state in `body`

```swift
// WRONG — any state change re-renders everything below
var body: some View {
    Text("\(store.state.count)")
}
```

### ❌ Never: create the Store inside `body`

```swift
// WRONG — a new Reactable on every render, losing all state
var body: some View {
    let store = Store(CounterReactable())
    ...
}

// RIGHT
@StateObject private var store = Store(CounterReactable())
```

Use `@StateObject` when the view owns the Reactable, `@ObservedObject` when it is
handed one from outside (navigation, a parent).

### ✅ Do: use `binding` / `updateOn(_:content:action:)` for two-way inputs

```swift
store.updateOn(\.name) { $name in
    TextField("Name", text: $name)
} action: { change in
    .nameChanged(change.new)
}
```

The action generator turns the write into a normal Action, so the one-way flow
still holds. The `BindingValue` gives you `old` and `new`.

### ❌ Never: write to state through a binding without an action

Bypassing the action means `mutate` never runs and nobody can observe the change.

---

## 4. Parent and child Reactables

### ✅ Do: hold the child in the parent's State and call it directly

```swift
struct State {
    let child = ChildReactable()
}

func reduce(state: inout State, mutation: Mutation) {
    state.child.action(.parentDidSomething)
}
```

No `await`, no `Task` — parent and child share the main actor.

### ✅ Do: observe a child with `child(_:).observe()`

```swift
final class ChildReactable: Reactable, ObservableEvent { }

// in the parent
func transformAction() -> AnyPublisher<Action, Never> {
    self.child(\.child).observe()
        .map(Action.childEvent)
        .eraseToAnyPublisher()
}
```

Conforming to `ObservableEvent` is all the child has to do. The pipeline calls
`send(_:state:)` for you once each action's mutation completes, so **every** action
is published; filter on the parent side for the ones you care about. Call
`send(_:state:)` yourself only for an event that is not an action.

`ObservableEventResult` carries `action`, `state` and `sourceId` — use `sourceId`
to tell instances of the same type apart.

### ❌ Never: observe children through the type-level `observe()` when you mean *this* child

```swift
// WRONG when several instances exist — you receive every instance's events
ChildReactable.observe()
```

`static observe()` is a broadcast across all instances of that type. For a
specific child, use `child(_:)`, which routes by key path.

### ❌ Never: have the child reach up into the parent

Children emit events; parents decide. A child holding a reference to its parent
creates a retain cycle and a two-way dependency that makes both untestable.

---

## 5. Shared and persisted state

### ✅ Do: pick the storage that matches the lifetime

```swift
struct State {
    @Shared(.userDefaults()) var isPremium: Bool = false
    @Shared(.file(path: "todo/")) var todos: [UUID: TodoItem] = [:]
    @Shared(.memory) var sessionScratch: String = ""
    @SharedViewState var drawable: Drawable = .init()
}
```

`@Shared` gives every holder of the same key the same value. `@SharedViewState`
adds view invalidation on top, for shared state that drives UI.

### ❌ Never: use `.file` or `.userDefaults` with a non-`Codable` value

```swift
// WRONG — crashes at init, not at compile time
@Shared(.userDefaults()) var session: Session = Session()   // Session isn't Codable
```

The check is a runtime `fatalError`, so a type-check or a build tells you nothing.
`.memory` and `.memorySingleton` have no such requirement.

### ❌ Never: use `@Shared` as a global mutable singleton

If two unrelated features write the same key, you have rebuilt a global variable
with extra steps. Shared state is for values that are genuinely one value.

### ✅ Do: use `@Emit` for one-shot events, not state

```swift
struct State {
    @Emit var toast: String = ""
}
```

```swift
someView
    .emit(\MyReactable.State.$toast, from: store) { message in
        showToast(message)
    }
```

`@Emit` fires every time it is assigned, **even when the new value equals the old
one** — it counts assignments rather than comparing values. That is what you want
for toasts, alerts and navigation triggers.

### ❌ Never: model a one-shot event as `@ViewState`

```swift
// WRONG — assigning the same message twice fires nothing the second time,
// and the "event" sticks around as state forever
@ViewState var toast: String = ""
```

Note the `$` in the key path: `.emit` takes a key path to the projected
`Emit<Value>`, not to the wrapped value.

### ✅ Do: mutate `@Shared` directly from `reduce`

```swift
func reduce(state: inout State, mutation: Mutation) {
    state.todos[id]?.finishedAt = Date()
}
```

`reduce` runs on the main actor, so pipeline writes are already serialised. There
is no race to guard against here.

`withLock` earns its keep when the **same key** is written from two isolation
domains. `@Shared` values are shared by key across the whole process, so a
Reactable on the main actor and an actor elsewhere can each be internally
serialised and still interleave with each other:

```swift
actor TodoSyncEngine {
    @Shared(.file(path: "todo/")) private var todos: [UUID: TodoItem] = [:]

    func finish(_ id: UUID) {
        self.$todos.withLock { $0[id]?.finishedAt = Date() }
    }
}
```

Note that `@Shared` is a property wrapper, so — unlike `@Dependency` — it cannot
live in a class that conforms to `Sendable`; the synthesised storage is a `var`.
An `actor` or a non-`Sendable` class works.

---

## 6. Navigation

### ✅ Do: conform the Reactable to `PathState` and push it

```swift
final class DetailReactable: Reactable, PathState { }

NavigationLink(reactable: DetailReactable()) {
    Text("Detail")
}
```

Or lazily, when constructing the Reactable eagerly would be wasteful:

```swift
NavigationLink(reactable: { DetailReactable() }) {
    Text("Detail")
}
```

`PathState` requires `Sendable`. A Reactable with a `let initialState` satisfies
that with a checked conformance; one with `var initialState` needs
`@unchecked Sendable` — see §1.

### ✅ Do: keep the path in State

```swift
struct State {
    @ViewState var path: ReactablePath = .init()
}
```

```swift
NavigationStack(reactablePath: $store.state.path) {
    RootView()
} destination: { reactable in
    switch reactable {
    case let reactable as DetailReactable:
        DetailView(store: Store(reactable))
    default:
        EmptyView()
    }
}
```

---

## 7. Dependency injection

### ✅ Do: define a key and expose it on `GlobalDependencyKey`

```swift
protocol ServiceProtocol: Sendable {
    func fetch() async throws -> [Item]
}

struct Service: ServiceProtocol { }

extension Service: DependencyInjectable {
    static var real: ServiceProtocol { Service() }
    static var preview: ServiceProtocol { Service.Mock() }
    static var test: ServiceProtocol { Service.TestMock() }
}

extension GlobalDependencyKey {
    var service: ServiceProtocol { self[Service.self] }
}
```

`preview` and `test` default to `real`; override the ones you need. Which one you
get is decided by `AppEnvironment` — previews, XCTest, or real — and is resolved
once per process.

### ✅ Do: annotate the type when using `@Dependency`

```swift
@Dependency(\.service) var service: ServiceProtocol
```

### ❌ Never: omit the type annotation on a member

```swift
struct Trip {
    // WRONG — will not compile
    @Dependency(\.service) var service
}
```

A member declaration goes through the macro, which cannot infer the type from the
key path. This is the single most common migration error. In a local scope the
property wrapper is chosen instead and does infer it — see §7.

### ✅ Do: hold dependencies anywhere, including background types

```swift
final class Repository: Sendable {
    @Dependency(\.service) var service: ServiceProtocol
}

actor SyncEngine {
    @Dependency(\.service) var service: ServiceProtocol
}
```

Resolution is lazy and lock-guarded, so this is safe from any thread.

### ✅ Do: declare dependencies inside a local scope

```swift
private func configureAudio() async throws {
    @Dependency(\.audioSessionManager) var manager: AudioSessionManagerProtocol
    try await manager.activateSession()
}
```

Works in every local position: function bodies, initializers, closures, and
accessor bodies — implicit ones included.

### ✅ Do: drop the type annotation in a local scope

```swift
struct Trip {
    var carType: CarType {
        @Dependency(\.configurationService) var service
        return service.get().carType
    }
}
```

`@Dependency` is two things under one name: an attached macro, and a property
wrapper. The compiler takes the macro wherever member storage is valid, and the
wrapper everywhere else — including the body of an implicit getter, which the
macro cannot tell apart from a member declaration.

They behave the same. Both own a `DependencyStorage`: resolution is deferred to
first access, guarded by that storage's own lock, and cached for the lifetime of
the declaration. Two member instances resolve twice; two evaluations of a local
declaration resolve twice; one declaration accessed repeatedly resolves once.

The one difference you can see is the annotation: the macro cannot infer the type
from the key path and requires it, while the wrapper infers it. Annotating is
always correct; omitting it only works where the wrapper is chosen.

### ❌ Never: use `@Dependency` as an `extension` or `enum` member

```swift
// WRONG — "extensions must not contain stored properties"
extension Trip {
    @Dependency(\.service) var service: ServiceProtocol
}
```

The macro expands to a stored property and the wrapper needs one, so neither can
live there. Declare it locally inside the member that uses it.

### ✅ Do: declare the conformance isolated when the dependency itself is main-actor bound

```swift
@MainActor
final class SessionStore { static let shared = SessionStore() }

extension SessionStore: @MainActor DependencyInjectable {
    static var real: SessionStore { .shared }
}

extension GlobalDependencyKey {
    @MainActor var sessionStore: SessionStore { self[SessionStore.self] }
}
```

There is **one** protocol. Isolation belongs on the conformance, and the compiler
then refuses to resolve that dependency off the main actor. If you find yourself
looking for a `MainActorDependencyInjectable`, it no longer exists — this replaced it.

### ❌ Never: use `static var real` when you need a single instance

```swift
// WRONG — a computed property builds a new instance on every resolution
static var real: ServiceProtocol { Service() }

// RIGHT for singletons
static let real: ServiceProtocol = Service.shared
```

Both spellings are valid; they just mean different things. Pick deliberately.

### ⚠️ Know this gap: `Sendable` is not enforced through `@Dependency`

A `Sendable` type can hold a non-`Sendable` dependency and the compiler will not
diagnose it — macro-generated storage escapes that check. Hand-written code with
the same shape *is* rejected. So when a dependency crosses isolation boundaries,
make it `Sendable` yourself; the compiler will not remind you.

### ✅ Do: use `@ViewDependency` only inside SwiftUI views

```swift
struct ProfileView: View {
    @ViewDependency(\.service) var service: ServiceProtocol
}
```

It is a `DynamicProperty` backed by `@State`, so the value survives view
re-creation. Outside a `View` it buys nothing — use `@Dependency`.

### ✅ Do: use factories when construction needs a payload

```swift
final class Detail: Factory {
    struct Payload { let id: UUID }
    init(payload: Payload) { }
}

extension Detail: DependencyInjectable {
    typealias DependencyType = Detail.Factory
    static var real: Detail.Factory { .init() }
}
```

Use `AnyFactory<Output, Payload>` when callers should see a protocol rather than
the concrete type. There is no `ViewFactory` — it was a duplicate of `Factory`
that differed only by `@MainActor`, and it is gone.

---

## 8. UIKit

```swift
final class ProfileViewController: UIViewController, ReactableView {
    var cancellables = Set<AnyCancellable>()

    func bind(reactable: ProfileReactable) {
        reactable.state
            .map(\.title)
            .removeDuplicates()
            .sink { [weak self] title in self?.titleLabel.text = title }
            .store(in: &self.cancellables)
    }
}
```

Setting `reactable` cancels the previous subscriptions and calls `bind` again, so
`bind` must be safe to run more than once. Always capture `[weak self]` in sinks.

---

## 9. Testing

### ✅ Do: drive tests with `Stub`

```swift
struct CounterReactableTests {
    @Test
    func increments() async {
        let stub = Stub(CounterReactable())
        await stub.action(.increase)
        #expect(stub.currentState.count == 1)
    }
}
```

`Stub` is `@unchecked Sendable` and its initializer is nonisolated, so a plain
test suite can construct one — no `@MainActor` on the suite. `Stub.setState(_:)`
*is* main-actor isolated, so a suite that seeds state needs `@MainActor` (or an
`await`).

`Stub.action` awaits the whole pipeline, so no sleeping or polling is needed.
`setState(_:)` seeds a starting state.

Which dependency you get is decided by `AppEnvironment`, which sniffs the process
once: `XCODE_RUNNING_FOR_PREVIEWS` for `.preview`, then `NSClassFromString("XCTest")`
for `.test`, else `.real`. So a test bundle that links XCTest gets `static var test`.
Detection is a side effect of the environment, not something you can set: there is
no scoped override, no `withDependencies { }`, and `AppEnvironment.current` is
internal with no setter.

That makes the sniff a trap worth knowing about: a bundle that uses swift-testing
(`import Testing`) without linking XCTest has no `XCTest` class to find, so it can
resolve to `.real` and quietly run your tests against production dependencies. If
a test needs a specific double, inject it explicitly rather than trusting the
environment to pick one.

---

## 10. Diagnostics

`ReactableInstrument` measures mutate/reduce/effect timings and is **DEBUG-only**.

### ❌ Never: verify with a build that has `DEBUG` off

Type-checking or building without `DEBUG` compiles instrumentation and its tests
out entirely, so a green result proves nothing about them. Check both
configurations before claiming a build is clean.

---

## Quick reference — the errors you will actually hit

| Message | Cause | Fix |
|---|---|---|
| `cannot expand accessor macro on variable declared with 'let'` | `@Dependency` on a `let` | Use `var`; the macro's own storage is already a `let` |
| `@Dependency requires an explicit type annotation` | `@Dependency` without a type | Annotate: `var x: Service` |
| `@Dependency cannot be applied to a property with an initial value` | `@Dependency(\.x) var x: T = T()` | Drop the initial value; the key path supplies it |
| `property wrapper can only be applied to a 'var'` | `@ViewState` / `@Shared` / `@ViewDependency` on a `let` | Use `var` — this one is about wrappers, not the macro |
| `conformance of '...' to protocol 'Reactable' crosses into main actor-isolated code` | `@MainActor` on a Reactable conformance | Drop it; the protocol is nonisolated |
| `main actor-isolated default value in a nonisolated context` | Resolving a `@MainActor` conformance off-main | Resolve on the main actor, or drop the isolated conformance |
| `stored property ... of 'Sendable'-conforming class is mutable` | `@ViewState` / `@Shared` in a `Sendable` class, or `var initialState` on a `PathState` Reactable | For a dependency use `@Dependency`, whose member form is macro-generated storage; for `initialState`, use `let` or `@unchecked Sendable` |
