//
//  Tag.swift
//  App
//
//  Created by Finer  Vine on 2020/5/24.
//

import Vapor
import Fluent

final class Tag: Model, Content {
    // Name of the table or collection.
    static let schema: String = "tags"

    // Unique identifier for this Tag.
    @ID(key: .id)
    var id: UUID?

    // The Tag's name.
    @Field(key: "name")
    var name: String
    
    // 这里是 行星
    @Siblings(through: StarTag.self, from: \.$tag, to: \.$star)
    var stars: [Star]
    
    // Creates a new, empty Tag.
    init() {}

    // Creates a new Tag with all properties set.
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
