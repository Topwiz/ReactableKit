//
//  UIKitExample.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 2/2/25.
//

import Foundation
import UIKit
import SwiftUI

final class UIKitExampleReactable: Reactable {
    
    enum Action {
        case changeTitle
    }
    
    enum Mutation {
        case setTitle(String)
    }
    
    struct State: PathState {
        var title: String = ""
    }
    
    var initialState: State = .init()
    
    func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case .changeTitle:
            return .just(.setTitle(randomString(length: 5)))
        }
    }
    
    func reduce(state: inout State, mutate: Mutation) {
        switch mutate {
        case let .setTitle(title):
            state.title = title
        }
    }


}

final class UIKitView: UIView {
    
    let reactable: UIKitExampleReactable = .init()
    var cancellables: Set<AnyCancellable> = []
    
    let titleLabel = UILabel()
    let button = UIButton()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.titleLabel)
        self.addSubview(self.button)
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.titleLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.titleLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.button.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 20),
            self.button.centerXAnchor.constraint(equalTo: self.centerXAnchor),
        ])
        self.button.setTitleColor(.black, for: .normal)
        self.button.setTitle("Change Title", for: .normal)
        self.button.addTarget(self, action: #selector(self.buttonTapped), for: .touchUpInside)
        self.bind()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func buttonTapped() {
        self.reactable.action(.changeTitle)
    }
    
    func bind() {
        
        self.reactable.state.map { $0.title }
            .debug()
            .distinctUntilChanged()
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] title in
                self?.titleLabel.text = title
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

