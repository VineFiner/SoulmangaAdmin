//
//  queues.swift
//  App
//
//  Created by Finer  Vine on 2020/5/3.
//

import Vapor
import Queues

func queues(_ app: Application) throws {
    // MARK: Queues Configuration
    try app.queues.use(.memory())
    // MARK: Jobs
    app.queues.add(EmailJob())
}
