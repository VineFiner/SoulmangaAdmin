//
//  UserToken.swift
//  App
//
//  Created by Finer  Vine on 2020/5/3.
//

import Fluent
import Vapor

final class UserToken: Model, Content {
    static let schema = "user_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "value")
    var value: String

    @Parent(key: "user_id")
    var user: User

    @Field(key: "expires_at")
    var expiresAt: Date
    
    init() { }

    init(id: UUID? = nil, value: String, userID: User.IDValue, expiresAt: Date = Date().addingTimeInterval(Constants.ACCESS_TOKEN_LIFETIME)) {
        self.id = id
        self.value = value
        self.$user.id = userID
        self.expiresAt = expiresAt
    }
}

// MARK: Auth
extension UserToken: ModelTokenAuthenticatable {
    static let valueKey = \UserToken.$value
    static let userKey = \UserToken.$user

    var isValid: Bool {
        switch self.expiresAt.compare(Date()) {
        case .orderedAscending, .orderedSame:
            return false
        case .orderedDescending:
            return true
        }
    }
}
