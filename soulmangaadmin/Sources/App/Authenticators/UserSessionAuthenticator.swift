//
//  UserSessionAuthenticator.swift
//  App
//
//  Created by Finer  Vine on 2020/5/5.
//

import Fluent

// MARK: Session
// Allow this model to be persisted in sessions.
extension User: ModelSessionAuthenticatable { }
