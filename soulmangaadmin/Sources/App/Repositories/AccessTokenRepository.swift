//
//  AccessTokenRepository.swift
//  App
//
//  Created by Finer  Vine on 2020/5/3.
//
// 可以直接使用 JWT Payload 进行替换
import Vapor
import Fluent

protocol AccessTokenRepository: Repository {
    func create(_ token: UserToken) -> EventLoopFuture<Void>
    func find(id: UUID?) -> EventLoopFuture<UserToken?>
    func find(token: String) -> EventLoopFuture<UserToken?>
    func delete(_ token: UserToken) -> EventLoopFuture<Void>
    func count() -> EventLoopFuture<Int>
    func delete(for userID: UUID) -> EventLoopFuture<Void>
}

struct DatabaseAccessTokenRepository: AccessTokenRepository, DatabaseRepository {
    let database: Database
    
    func create(_ token: UserToken) -> EventLoopFuture<Void> {
        return token.create(on: database)
    }
    
    func find(id: UUID?) -> EventLoopFuture<UserToken?> {
        return UserToken.find(id, on: database)
    }
    
    func find(token: String) -> EventLoopFuture<UserToken?> {
        return UserToken.query(on: database)
            .filter(\.$value == token)
            .first()
    }
    
    func delete(_ token: UserToken) -> EventLoopFuture<Void> {
        token.delete(on: database)
    }
    
    func count() -> EventLoopFuture<Int> {
        return UserToken.query(on: database)
            .count()
    }
    
    func delete(for userID: UUID) -> EventLoopFuture<Void> {
        UserToken.query(on: database)
            .filter(\.$user.$id == userID)
            .delete()
    }
}

extension Application.Repositories {
    var accessTokens: AccessTokenRepository {
        guard let factory = storage.makeAccessTokenRepository else {
            fatalError("AccessToken repository not configured, use: app.repositories.use")
        }
        return factory(app)
    }
    
    func use(_ make: @escaping (Application) -> (AccessTokenRepository)) {
        storage.makeAccessTokenRepository = make
    }
}
