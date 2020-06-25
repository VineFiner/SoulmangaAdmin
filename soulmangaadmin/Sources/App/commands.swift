//
//  commands.swift
//  App
//
//  Created by Finer  Vine on 2020/6/21.
//

import Foundation
import Vapor

func configCommands(_ app: Application) throws {
    app.commands.use(CrawBookInfoCommand(), as: "craw")
    app.commands.use(HelloCommand(), as: "hello")
}
