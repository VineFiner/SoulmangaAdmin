//
//  WebsiteController.swift
//  App
//
//  Created by Finer  Vine on 2020/4/12.
//

import Fluent
import Vapor

struct WebsiteController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let web = routes
        
        // 非保护 路由
        // register
        web.get("register", use: renderRegister(req:))
        // register api
        web.post("register", use: register(req:))
        web.frontend(.noAuthed) { (builder) in
            builder.get("sign-in", use: renderSessionLogin)
            builder.post("sign-in", use: loginSession(req:))
            builder.get("logout", use: sessionLogout)
        }
        
        // 受保护路由
        //session protected
        // Basic middleware to redirect unauthenticated requests to the supplied path
        let redirectAuth = User.redirectMiddleware(path: "/sign-in")
        web.frontend().group([redirectAuth]) { (builder) in
            builder.get("", use: sessionUserInfo)
        }
    }
    
    /// render register view
    func renderRegister(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("register")
    }
    /// render login view
    func renderLogin(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("login")
    }
    /// render Session login view http://127.0.0.1:8080/auth/sign-in
    func renderSessionLogin(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("login")
    }
    /**
     curl -H "Content-Type:application/json" \
     -X POST \
     -d '{
         "name": "Vapor",
         "email": "test@vapor.codes",
         "password": "secret123",
         "confirmPassword": "secret123"
     }' \
     http://127.0.0.1:8080/register/
     */
    func register(req: Request) throws -> EventLoopFuture<Response> {
        try RegisterRequest.validate(req)
        let registerRequest = try req.content.decode(RegisterRequest.self)
        guard registerRequest.password == registerRequest.confirmPassword else {
            throw AuthenticationError.passwordsDontMatch
        }
        return User.query(on: req.db)
            .filter(\.$email == registerRequest.email)
            .first()
            .flatMap { (result) -> EventLoopFuture<Response> in
                if let _ = result {
                    return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "User is exist"))
                }
                do {
                    let user = try User(
                        fullName: registerRequest.fullName,
                        email: registerRequest.email,
                        passwordHash: Bcrypt.hash(registerRequest.password),
                        isEmailVerified: true
                    )
                    return user.save(on: req.db).map { (void) -> (Response) in
                        return req.redirect(to: "/sign-in")
                    }
                } catch {
                    return req.eventLoop.makeFailedFuture(error)
                }
            }
    }
    
    // Session post
    func loginSession(req: Request) throws -> EventLoopFuture<Response> {
        try LoginRequest.validate(req)
        let loginRequest = try req.content.decode(LoginRequest.self)
        
        return req.users
            .find(email: loginRequest.email)
            .unwrap(or: AuthenticationError.invalidEmailOrPassword)
            .guard({ $0.isEmailVerified }, else: AuthenticationError.emailIsNotVerified)
            .flatMap { user -> EventLoopFuture<User> in
                return req.password
                    .async
                    .verify(loginRequest.password, created: user.passwordHash)
                    .guard({ $0 == true }, else: AuthenticationError.invalidEmailOrPassword)
                    .transform(to: user)
        }
        .map { (user) -> Response in
            req.session.authenticate(user)
            return req.redirect(to: "/")
        }
    }
    
    // http://127.0.0.1:8080/auth/session/info
    func sessionUserInfo(req: Request) throws -> EventLoopFuture<View> {
        struct PublicUser: Codable {
            var email: String
            var name: String
        }
        let user = try req.auth.require(User.self)
        let context = PublicUser(email: user.email, name: user.fullName)
        return req.view.render("info", context)
    }
    // logout
    func sessionLogout(req: Request) throws -> Response {
        req.auth.logout(User.self)
        req.session.unauthenticate(User.self)
        return req.redirect(to: "/")
    }
}
