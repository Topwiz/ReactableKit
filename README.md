# ReactableKit 

## Introduction

ReactableKit은 ReactorKit의 기본 구조를 바탕으로 SwiftUI에서의 상태 관리 및 비즈니스 로직을 효율적으로 관리하기 위해 개발되었습니다.

## Requirements

- iOS 15.0+
- Swift 5+

## Usage

### 1. Reactable 기본 구조

Reactable을 사용하려면 `Reactable` 프로토콜을 준수하는 클래스를 생성해야 합니다. 기본적으로 `Action`, `State`, `Mutation`을 정의하고 `func mutate`, `func reduce`을 구현합니다.

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

### 1-2. Reactable `transformAction`

`transformAction`을 사용하면 특정 이벤트를 감지하여 `Action`을 자동으로 트리거할 수 있습니다.

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

### 1-3. Reactable를 SwiftUI View에서 사용하는 예제

Reactable을 SwiftUI에서 사용할 때는 `Store`을 사용해서 상태 변화를 감지하고 `action`을 전달 합니다.

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

### 1-4. Reactable action
Reactable에 Action을 보낼때 완료시점을 알 수 있습니다.
```swift
Task {
    let state = try await ManagerSampleReactable.shared.action(.test)
}

let action = ManagerSampleReactable.shared.actionPublish(.test)
    .sink { state in
                
    }

ManagerSampleReactable.shared.action(.test) { state in
            
}
```

### 2. Property Wrapper
#### @ViewState
`@ViewState`는 값이 변경됐을때 View를 업데이트하기 위해 사용합니다. Reactable State 내에서 사용해야하며 ViewState를 붙이지 않는 다른 property들은 변경 되어도 View가 업데이트 되지 않습니다.
```swift
struct State {
    // 같은 값을 set하는 경우에는 view가 업데이트 되지 않습니다.
    @ViewState var count: Int = 1
    // 같은 값을 set하는 경우에도 view는 업데이트 됩니다.
    @ViewState(disableCheckingEquatable: true) var count1: Int = 1
}
```

#### @Shared
`@Shared` property wrapper는 Parent와 Child간에 State를 공유하기 위해 사용합니다.
```swift
struct SharedState: Codable, Equatable, Hashable {
    var username: String = ""
    var age: Int = 0
    var isPremium: Bool = false
}

struct State {
    @Shared(.memory) var sharedState = SharedState() 
    @ViewState var drawable: Drawable = .init()
}
```
- `@Shared`는 값이 변경이 되어도 View는 업데이트 되지 않습니다.

### 4. ObservableEvent
Child에서 Parent로 action을 전달해야할때 사용합니다.
```swift
// Child Reactable
class SharedStateChildReactable: Reactable { 
    enum Action: ObservableEvent {
        case parentAction(Int)
    }
}

// Parent Reactable
func transformAction() -> AnyPublisher<Action, Never> {
    let childEvent = SharedStateChildReactable.Action.observe()
        .filter {
            if case .parentAction = $0 { return true }
            return false
        }
        .map(Action.childAction)
        .eraseToAnyPublisher()
        
    return .merge([
        childEvent,
    ])
}
```

## License

ReactableKit은 MIT 라이선스를 따릅니다.
