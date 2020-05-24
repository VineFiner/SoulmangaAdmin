//
//  TagController.swift
//  App
//
//  Created by Finer  Vine on 2020/5/24.
//

import Fluent
import Vapor

struct TagController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let app = routes.grouped("cosmos")
        let tags = app.grouped("tags")
        // 创建标签
        tags.post(use: create)
        tags.get("all", use: index(req:))
    }
    /* 创建
         curl -i -X POST "http://127.0.0.1:8080/cosmos/tags" \
         -H "Content-Type: application/json" \
         -d '{"name": "large"}'
     */
    func create(req: Request) throws -> EventLoopFuture<Tag> {
        let tag = try req.content.decode(Tag.self)
        return tag.create(on: req.db)
            .map { tag }
    }
    /* 不分页
       curl -i -X GET "http://127.0.0.1:8080/cosmos/tags/all" \
        -H "Content-Type: application/json"
    */
    func index(req: Request) throws -> EventLoopFuture<[Tag]> {
        return Tag.query(on: req.db)
            .all()
    }
}
