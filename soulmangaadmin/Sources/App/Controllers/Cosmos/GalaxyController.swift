//
//  GalaxyController.swift
//  App
//
//  Created by Finer  Vine on 2020/5/18.
//

import Fluent
import Vapor

struct GalaxyController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let app = routes.grouped("cosmos")
        let galaxys = app.grouped("galaxys")
        // 创建星系
        galaxys.post(use: create)
        
        galaxys.get("all", use: index)
        galaxys.get("page", use: readAll)
        // 操作特定对象
        galaxys.group(":id") { (galaxy) in
            galaxy.get(use: read)
            galaxy.post(use: update)
            galaxy.delete(use: delete)
        }
    }
    
    /* 创建
         curl -i -X POST "http://127.0.0.1:8080/cosmos/galaxys" \
         -H "Content-Type: application/json" \
         -d '{"name": "Milky Way!"}'
     */
    func create(req: Request) throws -> EventLoopFuture<Galaxy.Output> {
        let input = try req.content.decode(Galaxy.Input.self)
        let galaxy = Galaxy(name: input.name)
        return galaxy.save(on: req.db).flatMapThrowing{ try Galaxy.Output(id: galaxy.requireID().uuidString, name: galaxy.name) }
    }
    /* 不分页
       curl -i -X GET "http://127.0.0.1:8080/cosmos/galaxys/all" \
        -H "Content-Type: application/json"
    */
    func index(req: Request) throws -> EventLoopFuture<[Galaxy.Output]> {
        return Galaxy.query(on: req.db)
            .all()
            .flatMapEachThrowing {
                try Galaxy.Output(id: $0.requireID().uuidString, name: $0.name)
            }
    }
    /* 分页
       curl -i -X GET "http://127.0.0.1:8080/cosmos/galaxys/page?page=1&per=2" \
        -H "Content-Type: application/json"
    */
    func readAll(req: Request) throws -> EventLoopFuture<Page<Galaxy.Output>> {
        return Galaxy.query(on: req.db)
            .paginate(for: req)
            .flatMapThrowing { page in
                try page.map { try Galaxy.Output(id: $0.requireID().uuidString, name: $0.name) }
            }
    }
    
    /* 按ID 查询
        curl -i -X GET "http://127.0.0.1:8080/cosmos/galaxys/<id>" \
            -H "Content-Type: application/json"
     */
    func read(req: Request) throws -> EventLoopFuture<Galaxy.Output> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        return Galaxy.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing { try Galaxy.Output(id: $0.requireID().uuidString, name: $0.name) }
    }
    /* 按 ID 更新
        curl -i -X POST "http://127.0.0.1:8080/cosmos/galaxys/<id>" \
            -H "Content-Type: application/json" \
            -d '{"name": "New Milky Way!"}'
     */
    func update(req: Request) throws -> EventLoopFuture<Galaxy.Output> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        let input = try req.content.decode(Galaxy.Input.self)
        return Galaxy.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { galaxy in
                galaxy.name = input.name
                return galaxy.save(on: req.db)
                    .flatMapThrowing { try Galaxy.Output(id: galaxy.requireID().uuidString, name: galaxy.name) }
            }
    }
    /* 按ID 删除
        curl -i -X GET "http://127.0.0.1:8080/cosmos/galaxys/<id>" \
            -H "Content-Type: application/json"
     */
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        return Galaxy.find(req.parameters.get("id"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { $0.delete(on: req.db) }
            .transform(to: .ok)
    }
}
