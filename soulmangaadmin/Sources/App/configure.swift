import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Leaf
import QueueMemoryDriver
import SwiftSMTPVapor
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    // Session
    app.middleware.use(app.sessions.middleware)
    app.sessions.use(.fluent)
    
    // Log
    app.middleware.use(LogMiddleware(logger: app.logger))
    // CORS
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors)
    /*
     Xcode Edit Scheme -> Run -> Options -> Working Directory -> `$(SRCROOT)`
     */
    app.views.use(.leaf)
    if !app.environment.isRelease {
        // 这里禁用缓存
        app.leaf.cache.isEnabled = false
    }
    
    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database"
        ), as: .psql)
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    
    // MARK: Session
    app.migrations.add(SessionRecord.migration)

    // MARK: App Config
    app.config = .environment
    
    // MARK: Email, 在 app config 之后
    let emailConfig = SwiftSMTPVapor.Configuration.init(server:
        .init(hostname: app.config.noReplayEmailHostName, port: 465), credentials:
        .init(username: app.config.noReplayEmailUserName,
              password: app.config.noReplayEmailPassword))
    app.swiftSMTP.initialize(with: emailConfig)
    
    // register routes
    try routes(app)
    // migration model
    try migrations(app)
    /// config jobs
    try queues(app)
    /// config server
    try services(app)
    
    // 开机自动执行任务
    try app.queues.startInProcessJobs()
    // 开机自动执行定时任务
//    try app.queues.startScheduledJobs()
    
    /// 这里根据环境进行配置
    /*
    if app.environment == .development {
        app.databases.default(to: .sqlite)
        try app.autoMigrate().wait()
    } else {
        app.databases.default(to: .psql)
    }
     */
//    app.http.server.configuration.port = 8081
    
    app.databases.default(to: .sqlite)
    
    // commands
    try configCommands(app)
    
    try app.autoMigrate().wait()
}
