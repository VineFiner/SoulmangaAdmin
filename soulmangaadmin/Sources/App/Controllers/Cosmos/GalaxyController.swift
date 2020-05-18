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
        app.post("galaxys", use: create)
        app.get("galaxys", "index", use: index)
        app.get("galaxys", use: readAll)
        app.get("galaxys", ":id", use: read)
        app.post("galaxys", ":id", use: update)
        app.delete("galaxys", ":galaxyID", use: delete)
    }
    
    /*
         curl -i -X POST "http://127.0.0.1:8080/galaxys" \
         -H "Content-Type: application/json" \
         -d '{"title": "Hello World!"}'
     */
    func create(req: Request) throws -> EventLoopFuture<Galaxy.Output> {
        let input = try req.content.decode(Galaxy.Input.self)
        let galaxy = Galaxy(name: input.name)
        return galaxy.save(on: req.db).flatMapThrowing{ try Galaxy.Output(id: galaxy.requireID().uuidString, name: galaxy.name) }
    }
    
    func index(req: Request) throws -> EventLoopFuture<[Galaxy.Output]> {
        return Galaxy.query(on: req.db).all().flatMapEachThrowing { try Galaxy.Output(id: $0.requireID().uuidString, name: $0.name)
        }
    }
    
    /*
       curl -i -X GET "http://127.0.0.1:8080/galaxys?page=2&per=2" \
        -H "Content-Type: application/json"
    */
    func readAll(req: Request) throws -> EventLoopFuture<Page<Galaxy.Output>> {
        return Galaxy.query(on: req.db)
            .paginate(for: req)
            .flatMapThrowing { page in
            try page.map { try Galaxy.Output(id: $0.requireID().uuidString, name: $0.name) }
        }
    }
    
    /*
        curl -i -X GET "http://127.0.0.1:8080/galaxys/<id>" \
            -H "Content-Type: application/json"
     */
    func read(req: Request) throws -> EventLoopFuture<Galaxy.Output> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        return Galaxy.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .map { Galaxy.Output(id: $0.id!.uuidString, name: $0.name) }
    }
    /*
        curl -i -X POST "http://127.0.0.1:8080/galaxys/<id>" \
            -H "Content-Type: application/json" \
            -d '{"title": "Write Vapor 4 book"}'
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
                    .map { Galaxy.Output(id: galaxy.id!.uuidString, name: galaxy.name) }
            }
    }
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        return Galaxy.find(req.parameters.get("galaxyID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { $0.delete(on: req.db) }
            .transform(to: .ok)
    }
}
