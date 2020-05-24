//
//  StarController.swift
//  App
//
//  Created by Finer  Vine on 2020/5/24.
//

import Fluent
import Vapor

struct StarController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let app = routes.grouped("cosmos")
        let stars = app.grouped("stars")
        // 创建行星
        stars.post(use: create)
        // 查询 星系
        stars.get("galaxies", use: readAll)
        // 查询 标签
        stars.get("tags", use: readWithTag)
        
        stars.group(":id") { (star) in
            // 添加标签
            star.post("tag", ":tagID", use: configTag)
        }
    }
    
    /* 创建
         curl -i -X POST "http://127.0.0.1:8080/cosmos/stars" \
         -H "Content-Type: application/json" \
         -d '{"name": "Sun", "galaxy": {"id": "7B7E0D61-0E2C-42A6-80DA-4461BF9A1263"}}'
     */
    func create(req: Request) throws -> EventLoopFuture<Star> {
        let star = try req.content.decode(Star.self)
        return star.create(on: req.db)
            .map { star }
    }
    /* 查询
       curl -i -X GET "http://127.0.0.1:8080/cosmos/stars/galaxies" \
        -H "Content-Type: application/json"
    */
    func readAll(req: Request) throws -> EventLoopFuture<[Galaxy]> {
        Galaxy.query(on: req.db).with(\.$stars).all()
    }
    /* 查询 带标签
       curl -i -X GET "http://127.0.0.1:8080/cosmos/stars/tags" \
        -H "Content-Type: application/json"
    */
    func readWithTag(req: Request) throws -> EventLoopFuture<[Star]> {
        Star.query(on: req.db).with(\.$tags).all()
    }
    /* 添加标签
       curl -i -X GET "http://127.0.0.1:8080/cosmos/stars/<id>/tag/<id>" \
        -H "Content-Type: application/json"
    */
    func configTag(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let star = Star.find(req.parameters.get("id"), on: req.db)
            .unwrap(or: Abort(.notFound))
        let tag = Tag.find(req.parameters.get("tagID"), on: req.db)
            .unwrap(or: Abort(.notFound))
        return star.and(tag).flatMap { (star, tag) in
            star.$tags.attach(tag, on: req.db)
        }.transform(to: .ok)
    }
}
