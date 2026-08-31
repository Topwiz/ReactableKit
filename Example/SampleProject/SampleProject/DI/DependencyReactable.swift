//
//  DependencyReactable.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 8/31/26.
//

import Foundation
import ReactableKit
import DependencyInjectableKit

final class DependencyReactable: Reactable {

    enum Action {
        case resolveOnMain
        case resolveOnBackground
        case resolveInActor
        case resolveMainActorOnly
        case clear
    }

    enum Mutation {
        case appendLog(String)
        case clear
    }

    struct State {
        @ViewState var logs: [String] = []
    }

    @Dependency(\.service) var service: ServiceProtocol
    @Dependency(\.factoryTestFactory) var factoryTestFactory: FactoryTest.DependencyType

    private let backgroundRepository = BackgroundRepository()
    private let backgroundActorRepository = BackgroundActorRepository()

    let initialState: State = State()

    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .resolveOnMain:
            let factory = self.factoryTestFactory.create(payload: .init())
            return .just(.appendLog("Reactable (@MainActor) -> \(self.service.test()) / \(factory.test())"))

        case .resolveOnBackground:
            let repository = self.backgroundRepository
            return .run { send in
                let message = await Task.detached { repository.load() }.value
                send(.appendLog(message))
            }

        case .resolveInActor:
            let repository = self.backgroundActorRepository
            return .run { send in
                let message = await repository.load()
                send(.appendLog(message))
            }

        case .resolveMainActorOnly:
            let session = GlobalDependencyKey().sessionStore
            session.signIn(as: "reactable-user")
            return .just(.appendLog("SessionStore (@MainActor conformance) -> \(session.userName)"))

        case .clear:
            return .just(.clear)
        }
    }

    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .appendLog(message):
            state.logs.append(message)

        case .clear:
            state.logs = []
        }
    }
}
