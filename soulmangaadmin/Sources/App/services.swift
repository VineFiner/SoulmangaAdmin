//
//  services.swift
//  App
//
//  Created by Finer  Vine on 2020/5/2.
//

import Vapor

func services(_ app: Application) throws {
    // 为了使用 random 方便
    app.randomGenerators.use(.random)
    app.repositories.use(.database)
}
