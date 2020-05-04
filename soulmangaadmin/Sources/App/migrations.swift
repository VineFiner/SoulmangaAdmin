//
//  migrations.swift
//  App
//
//  Created by Finer  Vine on 2020/5/2.
//

import Vapor

func migrations(_ app: Application) throws {
    // Initial Migrations
    // auth
    app.migrations.add(CreateUser())
    app.migrations.add(UserToken.Migration())
    app.migrations.add(CreateRefreshToken())
    app.migrations.add(CreateEmailToken())
    app.migrations.add(CreatePasswordToken())
    // admin
    app.migrations.add(CreateAdminUser())
    // todo
    app.migrations.add(CreateTodo())
}
