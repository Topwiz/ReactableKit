# Writing ReactableKit & DependencyInjectableKit Code

A rulebook for AI coding agents (and humans) working in a codebase that uses these
two libraries. Every rule below is stated as **Do this / Never do this** with the
reason attached, because the reason is what tells you when the rule stops applying.

Assumed baseline: Swift 6 language mode, iOS 16+.

---

## 0. The three facts everything else follows from

1. **`Reactable` is not actor-isolated; the pipeline runs on the main thread.**
   `mutate` and `reduce` are reached through `.receive(on: DispatchQueue.main)`,
   and state reads and writes hop through `DispatchQueue.main`. The contract is
   enforced at runtime, not by the type system, so you do not hop to the main
   actor to talk to a Reactable — and you do not annotate one either. The one
   part that is *not* on main is the `.run` body; see §2.
2. **State flows one way.** `action` → `mutate` → `Mutation` → `reduce` → `State`.
   Nothing else may write state.
3. **`@Dependency` is a property wrapper, and it resolves eagerly.** The value
   is read from `GlobalDependencyKey` in the wrapper's `init`, so it is fixed
   when the *owner* is created, not on first access. Use `@LazyDependency` when
   you need to defer that, and `@ViewDependency` inside a SwiftUI `View`.

---

## 0.5 Building this package

`Package.swift` declares `platforms: [.iOS(.v16)]` only. A plain `swift build`
on macOS therefore fails — `ReactableKit` imports `UIKit`, and
`DependencyInjectableKit` uses SwiftUI `@State`, which the macOS availability
floor rejects. Those errors are the platform, not your change.

Build and test against an iOS destination instead. The package exposes the
`ReactableKit` scheme for the library and `ReactableKit-Package` for the test
target; the test target's sources live in `Tests/ReactableKitTest` and are picked
up correctly despite the directory name.

Follow whatever build mechanism the project mandates. Do not conclude the tree is
broken from a failed macOS `swift build`.

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
The pipeline already runs on the main thread at runtime; leave the class
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
        return .run { [weak self] send in
            guard let self else { return }
            let items = try await self.repository.fetch()
            send(.setItems(items))
        } catch: { error, send in
            send(.setError(error.localizedDescription))
        }
    }
}
```

`.run` emits zero or more values through `send` and cancels with the
subscription. `send` is safe to call from any thread — the publisher delivers on
`DispatchQueue.main` before the pipeline reduces.

### ✅ Do: capture `[weak self]` in `.run`

The subscription holds the `Task`, and the `Task` holds the operation closure, so
a strong `self` keeps the whole Reactable alive until the operation finishes. For
a long-running or never-completing operation that is an unbounded lifetime
extension. Capture weakly and bail out:

```swift
return .run { [weak self] send in
    guard let self else { return }
    ...
}
```

Better still, capture only what you need — then there is no `self` to keep alive:

```swift
let repository = self.repository        // must be Sendable
return .run { send in
    send(.setItems(try await repository.fetch()))
}
```

### ⚠️ Know that capturing `self` in `.run` requires a `Sendable` Reactable

```swift
// WRONG on a plain Reactable — "capture of 'self' with non-Sendable type 'X'
// in a '@Sendable' closure"
final class X: Reactable {
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        .run { send in _ = self.repository }
    }
}
```

`operation` is `@Sendable`, so it cannot capture a non-`Sendable` `self` — weakly
or strongly. A `PathState` Reactable already carries `@unchecked Sendable` and
compiles; a plain one does not. Either add the conformance deliberately (§1) or
capture the `Sendable` values you need through the capture list.

### ⚠️ Know that the `.run` body is *not* on the main actor

`run(operation:catch:)` takes a plain `@Sendable async` closure and awaits it
inside `Task { @MainActor in }`, which is not enough: a nonisolated async
function does not inherit its caller's actor (SE-0338), so the body runs on the
cooperative pool. Measured, not inferred.

That is what you want for the I/O itself. But anything that must be on the main
thread — `currentState`, calling a child Reactable, UI — needs the isolation
spelled out on the closure:

```swift
return .run { @MainActor [weak self, currentState = self.currentState] send in
    guard let self else { return }
    let items = try await self.repository.fetch()
    send(.setItems(currentState.items + items))
}
```

Capturing the state *value* through the capture list, rather than reading
`self.currentState` inside the body, also avoids a `self` capture entirely — that
form compiles on a plain Reactable.

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

`mutate` and `reduce` already run on the main thread — the action stream is
`.receive(on: DispatchQueue.main)` before it reaches either. A `Task` here buys
you nothing, reorders the work, and breaks the ordering guarantees the pipeline
gives you. (The `.run` body is the one part that is *not* on main; see §2.)

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

### ⚠️ Know that reading `store.state` in `body` invalidates the whole body

```swift
// Works — but any @ViewState change re-evaluates this whole body
var body: some View {
    Text("\(store.state.count)")
}
```

This is correct and stays in sync: `objectWillChange` fires only when a
`@ViewState` or `@SharedViewState` value actually changes, and both wrappers
gate on `Equatable` first. The cost is scope — changing `title` also
re-evaluates a body that only reads `count`. Use `updateOn` when you want that
invalidation narrowed to one property.

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

No `await`, no `Task` — `reduce` is already on the main thread, and so is the
child's action.

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

`reduce` runs on the main thread, so pipeline writes are already serialised.
There is no race to guard against here.

`withLock` earns its keep when the **same key** is written from two isolation
domains. `@Shared` values are shared by key across the whole process, so a
Reactable's `reduce` on the main thread and an actor elsewhere can each be
internally serialised and still interleave with each other:

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

`preview` and `test` default to `real`; override the ones you need.

### ⚠️ Know that `AppEnvironment` is re-sniffed on every resolution

`AppEnvironment.current` is a computed property: it checks
`XCODE_RUNNING_FOR_PREVIEWS`, then `NSClassFromString("XCTest")`, then falls back
to `.real` — every single time a dependency is resolved. It is cheap but not
free, and it is not cached, so do not treat resolution as a one-time cost.

### ✅ Do: hold a dependency with `@Dependency`

```swift
struct Trip {
    @Dependency(\.service) var service
}
```

It is a property wrapper, so the type annotation is optional — `Value` is
inferred from the key path. Annotating is fine, just redundant.

Verified to compile as a member of a `struct`, `class`, `actor`, or
`@unchecked Sendable` class, and in any local scope: function bodies,
initializers, and accessor bodies including implicit getters.

### ❌ Never: expect `@Dependency` to be lazy

```swift
final class Repository {
    // resolves the moment Repository() is created
    @Dependency(\.service) var service
}
```

`Dependency.init` reads the key path immediately. If the dependency is expensive
to build, or must not exist yet when the owner is constructed, use
`@LazyDependency`.

### ⚠️ Know that `@LazyDependency` has a `mutating` getter

```swift
final class Repository {
    @LazyDependency(\.service) var service   // fine — class storage is mutable
}

struct Trip {
    @LazyDependency(\.service) var service
    func read() -> Item? {
        self.service.fetch()   // WRONG — "cannot use mutating getter on immutable value"
    }
}
```

It caches into its own storage on first read, which makes the getter `mutating`.
That is invisible in a `class` but bites in a `struct`: reading it needs a
`mutating` method or a `var` instance. On a `let` instance it never compiles.

### ❌ Never: put `@Dependency` in a checked-`Sendable` class

```swift
// WRONG — "stored property '_service' of 'Sendable'-conforming class is mutable"
final class Repository: Sendable {
    @Dependency(\.service) var service
}
```

A property wrapper is a mutable stored property. Either drop the `Sendable`
conformance, declare `@unchecked Sendable` (which is what a `PathState`
Reactable already does), or resolve locally inside the method that needs it:

```swift
final class Repository: Sendable {
    func load() async throws -> [Item] {
        @Dependency(\.service) var service
        return try await service.fetch()
    }
}
```

### ❌ Never: use `@Dependency` on a `let`, or as an `extension` member

```swift
// WRONG — "property wrapper can only be applied to a 'var'"
@Dependency(\.service) let service: ServiceProtocol

// WRONG — "extensions must not contain stored properties"
extension Trip {
    @Dependency(\.service) var service: ServiceProtocol
}
```

Both need storage the position cannot provide. In an extension, declare it
locally inside the member that uses it.

### ✅ Do: use `MainActorDependencyInjectable` for a main-actor-bound dependency

```swift
@MainActor
final class SessionStore { static let shared = SessionStore() }

extension SessionStore: MainActorDependencyInjectable {
    static var real: SessionStore { .shared }
}

extension GlobalDependencyKey {
    @MainActor var sessionStore: SessionStore { self[SessionStore.self] }
}
```

There are **two** protocols, and `GlobalDependencyKey` has a subscript for each —
the `MainActorDependencyInjectable` one is `@MainActor`. Pick by whether the
dependency itself is isolated.

### ❌ Never: reach a `@MainActor` key from a nonisolated context

```swift
// WRONG — "cannot form key path to main actor-isolated property 'sessionStore'"
func configure() {
    @Dependency(\.sessionStore) var session
}

// RIGHT
@MainActor
func configure() {
    @Dependency(\.sessionStore) var session
}
```

The key path itself cannot be formed off the main actor, so this fails at the
declaration — not at first use.

### ❌ Never: use `static var real` when you need a single instance

```swift
// WRONG — a computed property builds a new instance on every resolution
static var real: ServiceProtocol { Service() }

// RIGHT for singletons
static let real: ServiceProtocol = Service.shared
```

Both spellings are valid; they just mean different things. Pick deliberately.
This matters more than it looks, because `@Dependency` resolves per owner: ten
owners of a `static var real` key hold ten instances.

### ⚠️ Know this gap: `Sendable` is not enforced through `@Dependency`

`Dependency<Value>` is declared `@unchecked Sendable` regardless of `Value`, so
an `@unchecked Sendable` type can hold a non-`Sendable` dependency and the
compiler will not diagnose it. When a dependency crosses isolation boundaries,
make it `Sendable` yourself; the compiler will not remind you.

### ✅ Do: use `@ViewDependency` only inside SwiftUI views

```swift
struct ProfileView: View {
    @ViewDependency(\.service) var service
}
```

It is a `@MainActor` `DynamicProperty` backed by `@State`, so the value survives
view re-creation. `@LazyViewDependency` is the deferred variant. Outside a `View`
they buy nothing — use `@Dependency` or `@LazyDependency`.

### ✅ Do: use a factory when construction needs a payload

A plain dependency resolves to one value. When the type can only be built from
per-call data, register the **factory** instead: `@Dependency` hands you the
factory, and you call `create(payload:)` as often as you need.

```swift
final class Detail: Factory {
    struct Payload { let id: UUID }
    let payload: Payload
    init(payload: Payload) { self.payload = payload }
}

extension Detail: DependencyInjectable {
    typealias DependencyType = Detail.Factory
    static var real: Detail.Factory { .init() }
}

extension GlobalDependencyKey {
    var detailFactory: Detail.Factory { self[Detail.self] }
}
```

```swift
@Dependency(\.detailFactory) var detailFactory

let detail = self.detailFactory.create(payload: .init(id: id))
```

`Factory` is doing double duty here, and it trips people up: the protocol you
conform to is `Factory`, while `Detail.Factory` is a **typealias for
`DefaultFactory<Detail>`**, injected by a protocol extension. So the conformance
gives you the nested factory type for free — you never write
`DefaultFactory<Detail>` yourself.

### ✅ Do: erase to `AnyFactory` when you need per-environment implementations

`DependencyType = Detail.Factory` pins the concrete type, so `preview` and `test`
cannot substitute anything. Erase the output to a protocol and each environment
can hand back a *different* factory:

```swift
protocol ReportProtocol { func render() -> String }

struct Report: ReportProtocol, Factory {
    struct Payload { let month: Int }
    let payload: Payload
    init(payload: Payload) { self.payload = payload }
    func render() -> String { "real" }
}

struct ReportMock: ReportProtocol, Factory {
    let payload: Report.Payload          // same Payload — required
    init(payload: Report.Payload) { self.payload = payload }
    func render() -> String { "mock" }
}

extension Report: DependencyInjectable {
    typealias DependencyType = AnyFactory<ReportProtocol, Payload>

    static var real: DependencyType { DependencyType(factory: Report.Factory()) }
    static var test: DependencyType { DependencyType(factory: ReportMock.Factory()) }
}
```

Callers see `ReportProtocol`, so swapping the environment swaps the concrete type
underneath. This is the only way to mock a payload-constructed dependency.

### ❌ Never: give the mock its own `Payload`

```swift
struct ReportBadMock: ReportProtocol, Factory {
    struct Payload { let year: Int }     // WRONG
    ...
}
```

`AnyFactory.init(factory:)` is constrained to `F.Payload == Payload`, so this
fails with *"requires the types 'Report.Payload' and 'ReportBadMock.Payload' be
equivalent"*. Reuse the real type's `Payload` in the mock.

### ⚠️ Know that `AnyFactory.init(factory:)` force-casts

The convenience initialiser casts the built value to `Output` and calls
`fatalError` when it cannot. That is fine when `Output` is a protocol the
concrete type conforms to, which is the normal case. When it is not, pass a
`transform` and keep it total:

```swift
AnyFactory(factory: Report.Factory(), transform: { $0.render() })   // Output == String
```

### ✅ Do: use the `ViewFactory` family for main-actor-only types

```swift
struct ProfileView: View, ViewFactory {
    struct Payload { let userID: String }
    let payload: Payload
    init(payload: Payload) { self.payload = payload }
    var body: some View { Text(payload.userID) }
}

extension ProfileView: MainActorDependencyInjectable {
    typealias DependencyType = ProfileView.ViewFactory
    static var real: ProfileView.ViewFactory { .init() }
}

extension GlobalDependencyKey {
    @MainActor var profileViewFactory: ProfileView.ViewFactory { self[ProfileView.self] }
}
```

`ViewFactory` / `ViewDefaultFactory` / `AnyViewFactory` mirror the non-isolated
trio with `@MainActor` on everything, and pair with
`MainActorDependencyInjectable`. Use them for SwiftUI views and anything else
that can only be constructed on the main actor.

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
| `property wrapper can only be applied to a 'var'` | `@Dependency` / `@ViewState` / `@Shared` on a `let` | Use `var` |
| `cannot use mutating getter on immutable value` | `@LazyDependency` read from a non-`mutating` struct method, or a `let` instance | Use a `class`, a `mutating` method, or `@Dependency` |
| `non-static property '...' declared inside an extension cannot have a wrapper` | `@Dependency` as an `extension` member | Declare it locally inside the member |
| `cannot form key path to main actor-isolated property` | A `MainActorDependencyInjectable` key reached from a nonisolated context | Mark the reading context `@MainActor` |
| `conformance of '...' to protocol 'Reactable' crosses into main actor-isolated code` | `@MainActor` on a Reactable conformance | Drop it; the protocol is nonisolated |
| `main actor-isolated default value in a nonisolated context` | Resolving a `@MainActor` conformance off-main | Resolve on the main actor, or drop the isolated conformance |
| `stored property ... of 'Sendable'-conforming class is mutable` | Any property wrapper in a checked-`Sendable` class, or `var initialState` on a `PathState` Reactable | Resolve the dependency locally, or use `@unchecked Sendable`; for `initialState`, prefer `let` |
