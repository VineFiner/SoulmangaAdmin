import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import QueueMemoryDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database"
        ), as: .psql)
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    
    // MARK: App Config
    app.config = .environment
    
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
    
    /// 这里根据环境进行配置
    /*
    if app.environment == .development {
        app.databases.default(to: .sqlite)
        try app.autoMigrate().wait()
    } else {
        app.databases.default(to: .psql)
    }
     */
    app.databases.default(to: .sqlite)
    try app.autoMigrate().wait()
}
