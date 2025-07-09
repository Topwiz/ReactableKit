# 🚀 ReactableKit

## 📌 Introduction

**ReactableKit**은 **Combine** 기반으로 만들어진, **SwiftUI** 애플리케이션을 위한 가볍지만 강력한 상태 관리 프레임워크입니다.
이 프레임워크는 ReactorKit 아키텍처를 바탕으로 하여, 비즈니스 로직과 상태 변환을 효율적으로 처리할 수 있는 구조적인 방식을 제공합니다.

## 📋 Requirements

- ✅ iOS 16.0+
- ✅ Swift 5+


## ⚡ Usage

- [⚡ 기본 사용법](#-기본-사용법)
    - [1️⃣ Reactable의 핵심 구조](#1️⃣-reactable의-핵심-구조)
    - [2️⃣ `transformAction`을 통한 액션 변환](#2️⃣-transformaction을-통한-액션-변환)
    - [3️⃣ SwiftUI와의 Reactable 통합](#3️⃣-swiftui와의-reactable-통합)
    - [4️⃣ `updateOn`: SwiftUI 업데이트 최적화](#4️⃣-updateon-swiftui-업데이트-최적화)
    - [5️⃣ 액션 디스패치: 동기 vs 비동기](#5️⃣-액션-디스패치-동기-vs-비동기)
- [1️⃣ 프로퍼티 래퍼](#1️⃣-프로퍼티-래퍼)
    - [🎨 `@ViewState`](#-viewstate)
    - [🔄 `@Shared`](#-shared)
    - [📦 상태 추적을 위한 `@Emit` 사용](#-상태-추적을-위한-emit-사용)
      - [📌 상태에서 `@Emit` 사용하기](#-상태에서-emit-사용하기)
      - [📌 `emit(_:)` 구독하기](#-emit_-구독하기)
      - [📌 SwiftUI에서 `@Emit` 사용하기](#-swiftui에서-emit-사용하기)
- [2️⃣ `ObservableEvent` (부모 자식간 통신)](#2️⃣-observableevent-부모-자식간-통신)
- [3️⃣ `ReactableView` 프로토콜](#3️⃣-reactableview-프로토콜)
- [4️⃣ `DependencyInjectable` & `Factory` 패턴 사용법](#4️⃣-dependencyinjectable-and-factory-패턴-사용법)
    - [1. DependencyInjectable](#1-dependencyinjectable)
    - [2. Factory](#2-factory)
    - [3. AnyFactory](#3-anyfactory)

## 📦 Installation

### Swift Package Manager (SPM)

`ReactableKit`은 Swift Package Manager를 통해 쉽게 설치할 수 있습니다. Xcode에서 프로젝트를 열고, 메뉴에서 `File` > `Add Packages...`를 선택한 후, 아래 URL을 입력하세요:

```
https://github.com/topwiz/ReactableKit.git
```

또는 `Package.swift` 파일에 아래와 같이 직접 추가할 수도 있습니다:

```swift
dependencies: [
    .package(url: "https://github.com/topwiz/ReactableKit.git", from: `version`)
]
```

## ⚡ 기본 사용법

### 1️⃣ Reactable의 핵심 구조

`Reactable`을 사용하려면 `Reactable` 프로토콜을 준수하는 클래스를 생성하세요. `Action`, `Mutation`, `State`을 정의하고, `mutate(action:)`와 `reduce(state:mutation:)`를 구현합니다.

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
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
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
> ⚠️ `Store`을 사용하지 않는다면 Reactable `init`에 수동으로 `initialize()`을 불러줘야 합니다.

### 3️⃣ SwiftUI와의 Reactable 통합

`Store`를 사용하여 상태 변화를 감지하고 SwiftUI 뷰 내에서 `Action`을 디스패치할 수 있습니다.

```swift
struct CounterView: View {
    @StateObject var store = Store { 
        CounterReactable()
    }
    
    var body: some View {
        VStack {
            Text("\(self.store.state.count)")
                .font(.largeTitle)
                .padding()
            
            Button("Increase") {
                store.action(.increase)
            }
        }
    }
}
```

### 4️⃣ `updateOn`: SwiftUI 업데이트 최적화
`updateOn`은 SwiftUI 상태 관찰자로, 뷰가 필요한 경우에만 업데이트되도록 보장합니다.

```swift
struct CounterView: View {
    @ObservedObject var store = Store { 
        CounterReactable() 
    }

    var body: some View {
        VStack(spacing: 20) {
            // ✅ `count`가 변경될 때만 UI 업데이트. count1이 변경될 때는 업데이트되지 않음.
            
            self.store.updateOn(\.count) { value in
                Text("\(value)")
                    .font(.headline)
            }

           // 항상 업데이트됨
           
            Text("\(self.store.state.count1)")
                .font(.headline)

           // Binding<Value> 예제
           
            self.store.updateOn(\.isOn1) { value in
                Toggle(isOn: value) {
                    Text("Toggle 1")
                }
            }

            // Action이 포함된 Binding<Value> 예제 
            
            self.store.updateOn(\.isOn1) { value in
                Toggle(isOn: value) {
                    Text("Toggle 1 updateOn with action")
                }
            } action: { newValue in
                .isOnChanged
            }
            
            // ForEach List 예제
            
            ForEach(self.store.state.list) { item in
                self.store.updateOn(\.list, for: item.id) { value in
                    Text("\(value.index)")
                        .font(.headline)
                }
            }
            
            // ForEach List 다중 뷰 예제
            
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

### 5️⃣ 액션 디스패치: 동기 vs 비동기

ReactableKit은 두 가지 액션 디스패치 방식을 제공합니다: **동기적 액션(Fire-and-Forget)**과 **비동기적 액션(Async/Await)**입니다.

#### 🔥 동기적 액션 (Fire-and-Forget)

일반적인 액션 디스패치 방식으로, 액션을 보내고 결과를 기다리지 않습니다.

```swift
// 기본 동기 액션
store.action(.increase)
store.action(.decrease)

// 반복적인 액션 실행
for _ in 0..<10 {
    store.action(.increase)
}
```
#### ⏳ 비동기적 액션 (Async/Await)

액션이 완전히 처리되고 상태가 업데이트된 후의 최종 상태를 반환받을 수 있습니다.

```swift
// 비동기 액션으로 최종 상태 받기

let finalState = await store.action(.increase)
print("액션 완료 후 카운트: \(finalState.count)")

// SwiftUI에서 비동기 액션 사용

Button("Async Increase") {
    Task {
        let result = await store.action(.increase)
        // 액션 완료 후 추가 작업 수행
        print("증가 완료, 현재 값: \(result.count)")
    }
}
```

### 1️⃣ 프로퍼티 래퍼

#### 🎨 `@ViewState`

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

#### 🔄 `@Shared`

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

#### 📦 상태 추적을 위한 `@Emit` 사용

`@Emit`은 값이 동일하게 설정되더라도 업데이트를 트리거합니다.

#### 📌 상태에서 `@Emit` 사용하기

```swift
struct MyState {
    @Emit var title: String = "Hello"
}
```

#### 📌 `emit(_:)` 구독하기

```swift
reactable.emit(\.$title)
    .sink { newValue in
        print("Title updated:", newValue)
    }
    .store(in: &cancellables)
```
#### 📌 SwiftUI에서 `@Emit` 사용하기
```swift
ZStack { }
.emit(\.$title, from: self.store) { value in
    print("Title updated:", value)
}
```

### 2️⃣ `ObservableEvent` (부모 자식간 통신)

`ObservableEvent`는 **자식 컴포넌트와 부모 컴포넌트간 액션을 전송**할 수 있게 해줍니다.
> ⚠️ Action이 끝난시점에 자녀의 State를 부모에게 전달하지만, 타이밍 이슈로 최신 state가 아닐수 있습니다. 어떤 자녀 Reactable이 보냈는지 판단하는 용도로 사용해주세요.

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

### 3️⃣ `ReactableView` 프로토콜
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
    // self.reactable이 설정되면 호출됩니다.
    func bind(reactable: UIKitReactable) { 

    }
}
```

## 4️⃣ `DependencyInjectable` & `Factory` 패턴 사용법

의존성 주입 시스템과 팩토리 패턴을 결합하여, real, preview, test 환경에서 객체 생성 및 의존성 관리를 간소화합니다.

### 1. DependencyInjectable

`DependencyInjectable` 프로토콜은 타입이 서로 다른 환경에 대한 의존성을 정의할 수 있도록 합니다.

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

@MainActor가 필요한 Factory는 `ViewFactory`를 사용합니다.

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

`AnyFactory`는 객체 생성 과정을 추상화하는 제네릭 래퍼입니다.
Factory를 이용하여 객체를 생성한 후, 변환 클로저를 통해 원하는 출력 타입으로 변환합니다.

```swift
// Define the protocol for testing
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



## 🏗️ Roadmap
- [ ] 💻 Mac Support
- [ ] 🚀 Performance Optimizations

## 🔗 References

- [ReactorKit](https://github.com/ReactorKit/ReactorKit)
- [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture)

## 📜 License

**ReactableKit** is available under the MIT license.
