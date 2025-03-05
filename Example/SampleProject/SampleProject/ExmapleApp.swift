//
//  ExmapleApp.swift
//  ReactableExmaple
//
//  Created by Jeehoon Son on 1/24/25.
//

import SwiftUI

@main
struct ExmapleApp: App {
    
    var body: some Scene {
        WindowGroup {
            NavigationStackView()
                .onAppear {
                    ManagerSampleContainer.shared.updateAsyncState()
                }
        }
    }
}
