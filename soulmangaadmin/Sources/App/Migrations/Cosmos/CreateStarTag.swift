//
//  CreateStarTag.swift
//  App
//
//  Created by Finer  Vine on 2020/5/24.
//

import Fluent

struct CreateStarTag: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("star_tag")
            .id()
            .field("star_id", .uuid, .required, .references("stars", "id"))
            .field("tag_id", .uuid, .required, .references("tags", "id"))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("star_tag").delete()
    }
}
