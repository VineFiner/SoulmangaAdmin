import Fluent
import Vapor

func routes(_ app: Application) throws {

    app.get("hello") { req -> String in
        return "Hello, world!"
    }

    let todoController = TodoController()
    app.post("todos", use: todoController.create)
    app.get("todos", "index", use: todoController.index)
    app.get("todos", use: todoController.readAll)
    app.get("todos", ":id", use: todoController.read)
    app.post("todos", ":id", use: todoController.update)
    app.delete("todos", ":todoID", use: todoController.delete)
    
    try app.register(collection: AuthenticationController())
    try app.register(collection: WebsiteController())

}
