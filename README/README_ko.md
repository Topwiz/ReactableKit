# 🚀 ReactableKit

## ⚡ 사용법

### 1️⃣ Reactable의 핵심 구조

`Reactable`을 사용하려면 `Reactable` 프로토콜을 준수하는 클래스를 생성하세요. `Action`, `State`, `Mutation`을 정의하고, `mutate(action:)`와 `reduce(state:mutate:)`를 구현합니다.

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

### 2️⃣ `transformAction`을 통한 액션 변환

`transformAction`은 자동으로 **이벤트 기반 액션 트리거**를 활성화합니다. 이는 타이머, 네트워크 이벤트 또는 외부 입력 소스를 처리하는 데 유용합니다.

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

### 3️⃣ SwiftUI와의 Reactable 통합

`Store`를 사용하여 상태 변화를 감지하고 SwiftUI 뷰 내에서 `Action`을 디스패치할 수 있습니다.

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

### 4️⃣ `updateOn`: SwiftUI 업데이트 최적화
`updateOn`은 강력한 SwiftUI 상태 관찰자로, 뷰가 필요한 경우에만 업데이트되도록 보장합니다. 이 메서드는 keyPath가 일반 값(Value) 또는 Binding<Value>인지 자동으로 감지하여 불필요한 UI 리렌더링을 방지합니다.

#### 일반 값 기반 상태 업데이트에 updateOn 사용하기
일반 값(Int, Bool 등)을 사용할 때, updateOn은 값이 변경될 때만 뷰를 업데이트합니다.
- 최소한의 SwiftUI 리렌더링 보장
- 최적 성능을 위해 EquatableValueView 사용

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

### 5️⃣ Reactable에서 액션 디스패치

Reactable은 **액션 전송 및 완료 추적**을 위한 다양한 방법을 제공합니다.

```swift
// async-await 사용 예제
let reactable = CounterReactable()
Task {
    let state = try await reactable.action(.increase)
}

// Combine의 sink 사용 예제
let action = reactable.actionPublish(.increase)
    .sink { state in
        print(state)
    }

// Completion Handler 사용 예제
reactable.action(.increase) { result in
    print(result)
}
```

---

## 🎯 Advanced Features

### 1️⃣ 프로퍼티 래퍼

#### 🎨 `@ViewState`

`@ViewState`는 값이 변경될 때 **자동 UI 업데이트**를 보장합니다. `@ViewState`가 없는 프로퍼티는 UI 업데이트를 트리거하지 않습니다.

```swift
struct State {
    @ViewState var count: Int = 1
    @ViewState(ignoreEquality: true) var forceUpdate: Bool = false
}
```

#### 🔄 `@Shared`

`@Shared`는 **부모와 자식 컴포넌트 간의 상태 공유**를 가능하게 합니다.

```swift
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

### 2️⃣ `ObservableEvent` (자식 → 부모 통신)

`ObservableEvent`는 **자식 컴포넌트가 부모 컴포넌트로 액션을 전송**할 수 있게 해줍니다.

```swift
// 자식 Reactable
class ChildReactable: Reactable, ObservableEvent { 
    enum Action {
        case notifyParent(Int)
    }
}

// 부모 Reactable
func transformAction() -> AnyPublisher<Action, Never> {
    let childEvent = ChildReactable.observe() // 자식 Reactable의 액션과 변경된 상태를 관찰
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

### 3️⃣ `ReactableView` 프로토콜
UIKit 뷰에서 `ReactableView` 프로토콜을 사용합니다.

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
