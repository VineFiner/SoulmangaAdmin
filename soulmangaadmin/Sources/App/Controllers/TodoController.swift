import Fluent
import Vapor

struct TodoController {
    
    /*
         curl -i -X POST "http://127.0.0.1:8080/todos" \
         -H "Content-Type: application/json" \
         -d '{"title": "Hello World!"}'
     */
    func create(req: Request) throws -> EventLoopFuture<Todo.Output> {
        let input = try req.content.decode(Todo.Input.self)
        let todo = Todo(title: input.title)
        return todo.save(on: req.db).flatMapThrowing{ try Todo.Output(id: todo.requireID().uuidString, title: todo.title) }
    }
    
    func index(req: Request) throws -> EventLoopFuture<[Todo]> {
        return Todo.query(on: req.db).all()
    }
    
    /*
       curl -i -X GET "http://127.0.0.1:8080/todos?page=2&per=2" \
        -H "Content-Type: application/json"
    */
    func readAll(req: Request) throws -> EventLoopFuture<Page<Todo.Output>> {
        return Todo.query(on: req.db)
            .paginate(for: req)
            .flatMapThrowing { page in
            try page.map { try Todo.Output(id: $0.requireID().uuidString, title: $0.title) }
        }
    }
    
    /*
        curl -i -X GET "http://127.0.0.1:8080/todos/<id>" \
            -H "Content-Type: application/json"
     */
    func read(req: Request) throws -> EventLoopFuture<Todo.Output> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        return Todo.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .map { Todo.Output(id: $0.id!.uuidString, title: $0.title) }
    }
    /*
        curl -i -X POST "http://127.0.0.1:8080/todos/<id>" \
            -H "Content-Type: application/json" \
            -d '{"title": "Write Vapor 4 book"}'
     */
    func update(req: Request) throws -> EventLoopFuture<Todo.Output> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        let input = try req.content.decode(Todo.Input.self)
        return Todo.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { todo in
                todo.title = input.title
                return todo.save(on: req.db)
                    .map { Todo.Output(id: todo.id!.uuidString, title: todo.title) }
            }
    }
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        return Todo.find(req.parameters.get("todoID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { $0.delete(on: req.db) }
            .transform(to: .ok)
    }
}
