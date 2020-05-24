import Vapor
import Fluent

struct AuthenticationController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.versioned().group("auth") { auth in
            /// 注册用户，并发送电子邮件验证
            auth.post("register", use: register)
            /// 用现有用户登录，（需要电子邮件验证）
            auth.post("login", use: login)
            
            auth.group("email-verification") { emailVerificationRoutes in
                /// 用于通过 电子邮件验证令牌 验证电子邮件
                emailVerificationRoutes.get("", use: verifyEmail)
                
                /// （重新）将电子邮件验证发送到特定电子邮件
                emailVerificationRoutes.post("", use: sendEmailVerification)
            }
            
            /// 重置密码
            auth.group("reset-password") { resetPasswordRoutes in
                /// 发送带有令牌的重置密码电子邮件
                resetPasswordRoutes.post("", use: resetPassword)
                
                /// 验证给定的重置密码令牌, 基本无用
                resetPasswordRoutes.get("verify", use: verifyResetPasswordToken)
            }
            
            /// 前端页面，找回密码
            auth.post("recover", use: recoverAccount)
            
            /// 为用户提供新的访问令牌和刷新令牌
            auth.post("accessToken", use: refreshAccessToken)
            
            // Authentication required
            auth.group(UserToken.authenticator()) { authenticated in
                authenticated.get("me", use: getCurrentUser)
            }
        }
    }
    /* 注册用户
     curl -i -X POST "http://127.0.0.1:8080/api/auth/register" \
     -H "Content-Type: application/json" \
     -d '{"fullName": "Vapor", "email": "test@vapor.codes", "password": "secret11", "confirmPassword": "secret11"}'
     */
    private func register(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        try RegisterRequest.validate(req)
        let registerRequest = try req.content.decode(RegisterRequest.self)
        guard registerRequest.password == registerRequest.confirmPassword else {
            throw AuthenticationError.passwordsDontMatch
        }
        return req.password
            .async
            .hash(registerRequest.password)
            .flatMapThrowing { (passwordHash) -> User in
                return User(fullName: registerRequest.fullName, email: registerRequest.email, passwordHash: passwordHash)
        }
        .flatMap { (user) -> EventLoopFuture<Void> in
            return user.create(on: req.db)
                .flatMapErrorThrowing{ (error) in
                    if let dbError = error as? DatabaseError, dbError.isConstraintFailure {
                        throw AuthenticationError.emailAlreadyExists
                    }
                    throw error
            }
            .flatMap { (void) -> EventLoopFuture<Void> in
                // 这里是邮箱验证
                return req.emailVerifier.verify(for: user)
            }
        }
        .transform(to: .created)
    }
    /* 登录
     curl -i -X POST "http://127.0.0.1:8080/api/auth/login" \
     -H "Content-Type: application/json" \
     -d '{"email": "test@vapor.codes", "password": "secret11"}'
     */
    private func login(_ req: Request) throws -> EventLoopFuture<LoginResponse> {
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
        .flatMap { user -> EventLoopFuture<User> in
            // 删除旧token
            do {
                let deleteRefreshToken = try RefreshToken.query(on: req.db)
                    .filter(\.$user.$id == user.requireID())
                    .delete()
                let deleteAccessToken = try req.accessTokens.delete(for: user.requireID())
                
                return deleteRefreshToken.and(deleteAccessToken).transform(to: user)
            } catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }
        .flatMap { user in
            // 生成新 token
            do {
                let refreshValue = [UInt8].random(count: 16).base64
                let refreshToken = try RefreshToken(token: SHA256.hash(refreshValue), userID: user.requireID())
                
                let accessToken = try user.generateToken()
                
                //保存
                let saveRefresh = refreshToken.create(on: req.db)
                let saveAccess = accessToken.create(on: req.db)
                
                return saveRefresh.and(saveAccess).flatMapThrowing { (void) -> LoginResponse in
                    return LoginResponse(user: UserDTO(from: user),accessToken: accessToken.value, expiresIn: accessToken.expiresAt.timeIntervalSince1970,refreshToken: refreshValue)
                }
            } catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }
    }
    /*
     curl -i -X POST "http://127.0.0.1:8080/api/auth/accessToken" \
     -H "Content-Type: application/json" \
     -d '{"refreshToken": "MpUy0vYCsPqsyO7EoR2JzQ=="}'
     */
    private func refreshAccessToken(_ req: Request) throws -> EventLoopFuture<AccessTokenResponse> {
        let accessTokenRequest = try req.content.decode(AccessTokenRequest.self)
        let hashedRefreshToken = SHA256.hash(accessTokenRequest.refreshToken)
        
        return req.refreshTokens
            .find(token: hashedRefreshToken)
            .unwrap(or: AuthenticationError.refreshTokenOrUserNotFound)
            .flatMap { refresh -> EventLoopFuture<RefreshToken> in
                // 删除旧token
                let deleteRefreshToken = req.refreshTokens.delete(refresh)
                let deleteAccessToken = req.accessTokens.delete(for: refresh.$user.id)
                return deleteRefreshToken.and(deleteAccessToken).transform(to: refresh)
            }
            .guard({ $0.expiresAt > Date() }, else: AuthenticationError.refreshTokenHasExpired)
            .flatMap { req.users.find(id: $0.$user.id) }
            .unwrap(or: AuthenticationError.refreshTokenOrUserNotFound)
            .flatMap { user -> EventLoopFuture<(String, UserToken)> in
                do {
                    // 这里是刷新Token
                    let tokenValue = [UInt8].random(count: 16).base64
                    let refreshToken = try RefreshToken(token: SHA256.hash(tokenValue), userID: user.requireID())
                    
                    // 生成新的 token
                    let accessToken = try user.generateToken()
                    
                    //保存
                    let saveRefresh = refreshToken.create(on: req.db)
                    let saveAccess = accessToken.create(on: req.db)
                    return saveRefresh.and(saveAccess).transform(to: (tokenValue, accessToken))
                } catch {
                    return req.eventLoop.makeFailedFuture(error)
                }
        }
        .map { AccessTokenResponse(refreshToken: $0, expiresIn: $1.expiresAt.timeIntervalSince1970, accessToken: $1.value) }
    }
    /*
     curl -H "Authorization: Bearer PPMla5rf9aTlnK1Uu8zwIQ==" \
     -X GET "http://127.0.0.1:8080/api/auth/me"
     */
    private func getCurrentUser(_ req: Request) throws -> EventLoopFuture<UserDTO> {
        let user = try req.auth.require(User.self)
        return req.eventLoop.future(UserDTO(from: user))
    }
    /* 认证 Email
        curl -i -X GET "http://localhost:8080/api/auth/email-verification?token=acae384f2e" \
         -H "Content-Type: application/json"
     */
    private func verifyEmail(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let token = try req.query.get(String.self, at: "token")
        
        let hashedToken = SHA256.hash(token)
        
        return req.emailTokens
            .find(token: hashedToken)
            .unwrap(or: AuthenticationError.emailTokenNotFound)
            .flatMap { req.emailTokens.delete($0).transform(to: $0) }
            .guard({ $0.expiresAt > Date() },
                   else: AuthenticationError.emailTokenHasExpired)
            .flatMap {
                req.users.set(\.$isEmailVerified, to: true, for: $0.$user.id)
        }
        .transform(to: .ok)
    }
    /* 重设密码
     curl -i -X POST "http://127.0.0.1:8080/api/auth/reset-password" \
     -H "Content-Type: application/json" \
     -d '{"email": "test@vapor.codes"}'
     */
    private func resetPassword(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let resetPasswordRequest = try req.content.decode(ResetPasswordRequest.self)
        
        return req.users
            .find(email: resetPasswordRequest.email)
            .flatMap {
                if let user = $0 {
                    return req.passwordResetter
                        .reset(for: user)
                        .transform(to: .noContent)
                } else {
                    return req.eventLoop.makeSucceededFuture(.noContent)
                }
        }
    }
    /* 认证密码 Token
        curl -i -X GET "http://localhost:8080/api/auth/reset-password/verify?token=e704f18ab72bd3576c1dc97afe7fc37d9031b6419afb6cbe8a378a92030dcfa5"
     */
    private func verifyResetPasswordToken(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let token = try req.query.get(String.self, at: "token")
        
        let hashedToken = SHA256.hash(token)
        
        return req.passwordTokens
            .find(token: hashedToken)
            .unwrap(or: AuthenticationError.invalidPasswordToken)
            .flatMap { passwordToken in
                guard passwordToken.expiresAt > Date() else {
                    return req.passwordTokens
                        .delete(passwordToken)
                        .transform(to: req.eventLoop
                            .makeFailedFuture(AuthenticationError.passwordTokenHasExpired)
                    )
                }
                
                return req.eventLoop.makeSucceededFuture(.noContent)
        }
    }
    /* 验证并重设密码
     curl -i -X POST "http://127.0.0.1:8080/api/auth/recover/" \
     -H "Content-Type: application/json" \
     -d '{"password": "thisispassword", "confirmPassword": "thisispassword", "token": ""}'
     */
    private func recoverAccount(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        try RecoverAccountRequest.validate(req)
        let content = try req.content.decode(RecoverAccountRequest.self)
        
        guard content.password == content.confirmPassword else {
            throw AuthenticationError.passwordsDontMatch
        }
        
        let hashedToken = SHA256.hash(content.token)
        
        return req.passwordTokens
            .find(token: hashedToken)
            .unwrap(or: AuthenticationError.invalidPasswordToken)
            .flatMap { passwordToken -> EventLoopFuture<Void> in
                guard passwordToken.expiresAt > Date() else {
                    return req.passwordTokens
                        .delete(passwordToken)
                        .transform(to: req.eventLoop
                            .makeFailedFuture(AuthenticationError.passwordTokenHasExpired)
                    )
                }
                
                return req.password
                    .async
                    .hash(content.password)
                    .flatMap { digest in
                        req.users.set(\.$passwordHash, to: digest, for: passwordToken.$user.id)
                }
                .flatMap { req.passwordTokens.delete(for: passwordToken.$user.id) }
        }
        .transform(to: .noContent)
    }
    
    /* 重新发送 Email 验证
     curl -i -X POST "http://127.0.0.1:8080/api/auth/email-verification" \
     -H "Content-Type: application/json" \
     -d '{"email": "test@vapor.codes"}'
     */
    private func sendEmailVerification(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let content = try req.content.decode(SendEmailVerificationRequest.self)
        
        return req.users
            .find(email: content.email)
            .flatMap {
                guard let user = $0, !user.isEmailVerified else {
                    return req.eventLoop.makeSucceededFuture(.noContent)
                }
                return req.emailVerifier
                    .verify(for: user)
                    .transform(to: .noContent)
        }
    }
}
