//
//  VersionRoute.swift
//  App
//
//  Created by Finer  Vine on 2020/4/5.
//

import Vapor

struct VersionRoute {
    static let path: PathComponent = "api"
}

extension RoutesBuilder {
    func versioned(handler: (RoutesBuilder) -> ()) {
        return group(VersionRoute.path, configure: handler)
    }
    
    func versioned() -> RoutesBuilder {
        return grouped(VersionRoute.path)
    }
}

extension RoutesBuilder {
    
    fileprivate func middleware(_ type: FrontendMiddlewareType) -> [Middleware] {
        var middleware: [Middleware] = []
        if type == .all {
            middleware.append(User.sessionAuthenticator())
        }
        return middleware
    }
    
    func frontend(_ type: FrontendMiddlewareType = .all, handler: (RoutesBuilder) -> ()) {
        group(middleware(type), configure: handler)
    }
    
    func frontend(_ type: FrontendMiddlewareType = .all) -> RoutesBuilder {
        return grouped(middleware(type))
    }
}

enum FrontendMiddlewareType {
    case all
    case noAuthed
}
