//
//  Star.swift
//  App
//
//  Created by Finer  Vine on 2020/5/24.
//

import Vapor
import Fluent

final class Star: Model, Content {
    // Name of the table or collection.
    static let schema = "stars"

    // Unique identifier for this Star.
    @ID(key: .id)
    var id: UUID?

    // The Star's name.
    @Field(key: "name")
    var name: String

    // Reference to the Galaxy this Star is in.
    @Parent(key: "galaxy_id")
    var galaxy: Galaxy
    
    // 这里是标签
    @Siblings(through: StarTag.self, from: \.$star, to: \.$tag)
    var tags: [Tag]
    // Creates a new, empty Star.
    init() { }

    // Creates a new Star with all properties set.
    init(id: UUID? = nil, name: String, galaxyID: UUID) {
        self.id = id
        self.name = name
        // 通过 添加 `$` 来访问属性包装器
        self.$galaxy.id = galaxyID
    }
}
