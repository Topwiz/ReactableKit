//
//  TodoItem.swift
//  ExmapleApp
//
//  Created by Jeehoon Son on 3/21/25.
//

import Foundation

enum TodoFolder: Codable, Equatable {
    case red
    case yellow
    case green
    case blue
    case purple
}

struct TodoItem: Codable, Equatable, Identifiable {
    
    var id: UUID = .init()
    var title: String
    var content: String
    var createdAt: Date = .init()
    var finishedAt: Date?
    var folder: TodoFolder?
    
}
