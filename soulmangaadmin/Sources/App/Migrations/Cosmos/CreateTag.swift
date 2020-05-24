//
//  CreateTag.swift
//  App
//
//  Created by Finer  Vine on 2020/5/24.
//

import Fluent

struct CreateTag: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("tags")
            .id()
            .field("name", .string)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("tags").delete()
    }

}
