# 🚀 ReactableKit

## 📌 Introduction

**ReactableKit**은 **Combine** 기반으로 만들어진, **SwiftUI** 애플리케이션을 위한 가볍지만 강력한 상태 관리 프레임워크입니다.
이 프레임워크는 ReactorKit 아키텍처를 바탕으로 하여, 비즈니스 로직과 상태 변환을 효율적으로 처리할 수 있는 구조적인 방식을 제공합니다.

---

## 📚 목차

### ⚡ 기본 사용법
- [1️⃣ Reactable의 핵심 구조](#1️⃣-reactable의-핵심-구조)
- [2️⃣ `transformAction`을 통한 액션 변환](#2️⃣-transformaction을-통한-액션-변환)
- [3️⃣ SwiftUI와 Reactable](#3️⃣-swiftui와-reactable)
- [4️⃣ `updateOn`: SwiftUI 업데이트 최적화](#4️⃣-updateon-swiftui-업데이트-최적화)
- [5️⃣ 액션 dispatch](#5️⃣-액션-dispatch)

### 🎨 프로퍼티 래퍼
- [`@ViewState`](#-viewstate)
- [`@Shared`](#-shared)
- [`@Emit` 상태 추적](#-상태-추적을-위한-emit-사용)

### 🔧 기능
- [`ObservableEvent` (부모 자식간 통신)](#observableevent-부모-자식간-통신)
- [`ReactableView` 프로토콜](#reactableview-프로토콜)
- [`DependencyInjectable` & `Factory` 패턴](#dependencyinjectable--factory-패턴-사용법)

---

## ⚡ 기본 사용법

### 1️⃣ Reactable의 핵심 구조

`Reactable`을 사용하려면 `Reactable` 프로토콜을 준수하는 클래스를 생성하세요. `Action`, `Mutation`, `State`을 정의하고, `mutate(action:)`와 `reduce(state:mutation:)`를 구현합니다.

```swift
final class CounterReactable: Reactable {
    enum Action: Sendable {
        case increase
        case decrease
    }
    
    struct State: Sendable {
        var count: Int = 0
    }
    
    enum Mutation: Sendable {
        case setCount(Int)
    }
    
    let initialState = State()
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .increase:
            return .just(.setCount(currentState.count + 1))
            
        case .decrease:
            return .run { send in 
                await send(.setCount(self.currentState.count - 1))
            }
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

### 2️⃣ `transformAction`을 통한 액션 변환

`transformAction`은 자동으로 **이벤트 기반 액션 트리거**를 활성화합니다. 이는 타이머, 각종 액션을 Reactable Action으로 변환하는데 유용합니다.

```swift
func transformAction() -> AnyPublisher<Action, Never> {
    return Timer.publish(every: 5, on: .main, in: .common)
        .autoconnect()
        .map { _ in Action.autoIncrease }
        .eraseToAnyPublisher()
}
```

> ⚠️ **주의**: `Store` 안 쓰고 직접 만들 때는 `init`에서 `initialize()`를 꼭 호출해 주세요.

### 3️⃣ SwiftUI와 Reactable

`Store`를 사용하여 SwiftUI View에서 상태 변화를 감지하고 `Action`을 dispatch할 수 있습니다.

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

### 4️⃣ `updateOn`: SwiftUI 업데이트 최적화

특정 상태만 감시해서 SwiftUI 업데이트를 줄일 수 있어요:

```swift
struct OptimizedView: View {
    @ObservedObject var store = Store { CounterReactable() }

    var body: some View {
        VStack {
            // ✅ `count`만 바뀔 때 업데이트
            self.store.updateOn(\.count) { value in
                Text("\(value)")
                    .font(.headline)
            }
            
            // ✅ 액션이랑 같이 쓰기
            self.store.updateOn(\.isOn) { value in
                Toggle(isOn: value) {
                    Text("Toggle")
                }
            } action: { newValue in
                .toggleChanged
            }
            
            // ✅ ForEach 예시
            
            ForEach(self.store.state.items) { item in
                self.store.updateOn(\.items, for: item.id) { value in
                    Text("\(value.name)")
                }
            }
            
            // ✅ ForEach List 다중 뷰 예제
            
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

### 5️⃣ 액션 dispatch

#### 일반 Action
```swift
store.action(.increase)
```

#### Concurrency Action

- 액션이 완전히 처리되고 상태가 업데이트된 후의 최종 상태를 반환받을 수 있습니다.

```swift
let finalState = await store.asyncAction(.increase)
print("최종 카운트: \(finalState.count)")
```

---

## 🎨 프로퍼티 래퍼

### `@ViewState`
`@ViewState`는 값이 변경될 때 **자동 UI 업데이트**를 보장합니다. `@ViewState`가 없는 프로퍼티는 SwiftUI 업데이트를 트리거하지 않습니다.

```swift
struct State {
    @ViewState var count: Int = 1
    /// ignoreEquality = true 인 경우는 같은 값이 set이 되면 SwiftUI View가 업데이트 됩니다.
    @ViewState(ignoreEquality: true) var forceUpdate: Bool = false
    /// animation: 애니메이션을 설정한 경우는 값이 변경될 때 애니메이션을 적용합니다.
    @ViewState(animation: .default) var forceUpdate: Bool = false
}
```

### `@Shared`

`@Shared`는 **부모와 자식 컴포넌트 간의 상태 공유**를 가능하게 합니다.

```swift
/// `file`, `UserDefailt` 저장소는 Codable를 준수 해야합니다.
struct SharedState: Codable, Equatable {
    var username: String = ""
    var age: Int = 0
    var isPremium: Bool = false
}

struct State {
    @Shared(.file()) var sharedState = SharedState()
    @Shared(.file(path: "Test/")) var sharedState = SharedState() // 서브 폴더 경로
    @Shared var sharedState = SharedState()
    @Shared(key: "custom_key") var sharedState = SharedState() // 커스텀 키
    @ViewState var displayInfo: String = ""
}
```

> ⚠️ `@Shared`는 값이 변경되어도 UI를 자동으로 업데이트하지 않습니다.

### `@Emit` 상태 추적

`@Emit`은 값이 동일하게 설정되더라도 업데이트를 트리거합니다.

```swift
struct State {
    @Emit var title: String = "Hello"
}
```

#### `emit(_:)` 구독하기

```swift
reactable.emit(\.$title)
    .sink { newValue in
        print("제목이 바뀜:", newValue)
    }
    .store(in: &cancellables)
```

#### SwiftUI에서 `@Emit` 사용하기

```swift
ZStack { }
.emit(\.$title, from: self.store) { value in
    print("Title updated:", value)
}
```

---

## 🔧 기능

### `ObservableEvent` (부모 자식간 통신)

`ObservableEvent`는 **자식 컴포넌트와 부모 컴포넌트간 액션을 전송**할 수 있게 해줍니다.

```swift
// 자식 Reactable
class ChildReactable: Reactable, ObservableEvent {
    enum Action {
        case notifyParent(Int)
    }
}

// 부모 Reactable
func transformAction() -> AnyPublisher<Action, Never> {
     // 글로벌하게 모든 ChildReactable의 액션과 변경된 상태를 관찰
    let childEvent = ChildReactable.observe()
        .filter { result in // result 에는 발생한 액션과 액션이 끝난 시점의 Child State가 포함됩니다.
            if case .notifyParent = result.action { return true }
            return false
        }
        .map(Action.parentAction)
        .eraseToAnyPublisher()
        
    // 특정 reactable 액션을 관찰
    let localChildEvent = self.currentState.childReactable.observe()
        .filter { result in // result 에는 발생한 액션과 액션이 끝난 시점의 Child State가 포함됩니다.
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

### `ReactableView` 프로토콜

UIKit 뷰에서 @MainActor를 따르는 `ReactableView` 프로토콜을 사용합니다.

```swift
final class UIKitView: UIView {
    var cancellables: Set<AnyCancellable> = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.reactable = .init()
    }
}

extension UIKitView: ReactableView { 
    // self.reactable이 세팅되면 호출됩니다.
    func bind(reactable: UIKitReactable) { 

    }
}
```

### `DependencyInjectable` & `Factory` 패턴 사용법

의존성 주입 시스템과 팩토리 패턴을 결합하여, real, preview, test 환경에서 객체 생성 및 의존성 관리를 간소화합니다.

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

// MainActor를 따라야한다면 `MainActorDependencyInjectable`를 사용하세요.

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

#### 2. Factory

> @MainActor가 필요한 Factory는 `ViewFactory`를 사용합니다.

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

`AnyFactory`는 객체 생성 과정을 추상화하는 제네릭 래퍼입니다.
Factory를 이용하여 객체를 생성한 후, 변환 클로저를 통해 원하는 출력 타입으로 변환합니다.

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
