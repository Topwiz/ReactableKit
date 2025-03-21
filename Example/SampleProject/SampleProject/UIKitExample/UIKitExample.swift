//
//  UIKitExample.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 2/2/25.
//

import Foundation
import UIKit
import SwiftUI
import ReactableKit

final class UIKitExampleReactable: Reactable, PathState {
    
    enum Action {
        case changeTitle
        case updateEmit
    }
    
    enum Mutation {
        case setTitle(String)
        case setEmit
    }
    
    struct State {
        var title: String = ""
        @Emit var emitTest: Bool = false
    }
    
    var initialState: State = .init()
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .changeTitle:
            return .just(.setTitle(randomString(length: 5)))
            
        case .updateEmit:
            return .just(.setEmit)
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .setTitle(title):
            state.title = title
            
        case .setEmit:
            state.emitTest = state.emitTest
        }
    }


}

final class UIKitView: UIView {
    
    var cancellables: Set<AnyCancellable> = []
    
    let titleLabel = UILabel()
    let button = UIButton()
    let emitButton = UIButton()
    
    deinit {
        print("deinit UIKitView")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.reactable = .init()
        self.addSubview(self.titleLabel)
        self.addSubview(self.button)
        self.addSubview(self.emitButton)
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.button.translatesAutoresizingMaskIntoConstraints = false
        self.emitButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.titleLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.titleLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.button.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 20),
            self.button.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.emitButton.topAnchor.constraint(equalTo: self.button.bottomAnchor, constant: 20),
            self.emitButton.centerXAnchor.constraint(equalTo: self.centerXAnchor),
        ])
        self.button.setTitleColor(.black, for: .normal)
        self.button.setTitle("Change Title", for: .normal)
        self.button.addTarget(self, action: #selector(self.buttonTapped), for: .touchUpInside)
        self.emitButton.setTitleColor(.black, for: .normal)
        self.emitButton.setTitle("Emit Test", for: .normal)
        self.emitButton.addTarget(self, action: #selector(self.emitButtonTapped), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func buttonTapped() {
        self.reactable?.action(.changeTitle)
    }
    
    @objc func emitButtonTapped() {
        self.reactable?.action(.updateEmit)
    }
    
}

extension UIKitView: ReactableView {
    func bind(reactable: UIKitExampleReactable) {
        reactable.state.map { $0.title }
            .debug()
            .distinctUntilChanged()
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] title in
                self?.titleLabel.text = title
            })
            .store(in: &self.cancellables)
        
        reactable.emit(\.$emitTest)
            .debug()
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { value in
                print("$emitTest: \(value)")
            })
            .store(in: &self.cancellables)
    }
}

struct SwiftUIUIView: UIViewRepresentable {
 
    func makeUIView(context: Context) -> UIKitView {
        return UIKitView()
    }
    
    func updateUIView(_ uiView: UIKitView, context: Context) {
    }

}

