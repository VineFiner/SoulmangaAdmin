//
//  CreateAdminUser.swift
//  App
//
//  Created by Finer  Vine on 2020/5/4.
//

import Fluent
import Vapor

struct CreateAdminUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let password = [UInt8].random(count: 8).base64
        database.logger.info("\(password)")
        do {
            return try User(fullName: "vine", email: "vine@gmail.com", passwordHash: Bcrypt.hash(password), isAdmin: true, isEmailVerified: true).save(on: database)
        } catch {
            return database.eventLoop.future(())
        }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("users").delete()
    }
}
