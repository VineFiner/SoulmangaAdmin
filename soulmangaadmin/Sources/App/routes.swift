import Fluent
import Vapor

func routes(_ app: Application) throws {

    app.get("hello") { req -> String in
        return "Hello, world!"
    }
    
    try app.register(collection: AuthenticationController())
    try app.register(collection: WebsiteController())
    
    try cosomosRoutes(app)
}
/// cosomos
func cosomosRoutes(_ app: Application) throws {
    try app.register(collection: GalaxyController())
}
