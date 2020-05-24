import Fluent
import Vapor

func routes(_ app: Application) throws {

    app.get("hello") { req -> String in
        return "Hello, world!"
    }
    
    try app.register(collection: AuthenticationController())
    try app.register(collection: WebsiteController())
    
    try cosomosRoutes(app)
    try booksRoutes(app)
}
/// books
func booksRoutes(_ app: Application) throws {
    try app.register(collection: BookController())
    try app.register(collection: CrawClientController())
}
/// cosomos
func cosomosRoutes(_ app: Application) throws {
    try app.register(collection: GalaxyController())
    try app.register(collection: StarController())
    try app.register(collection: TagController())
}
