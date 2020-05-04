import Vapor

extension Request {
    // MARK: Repositories
    var users: UserRepository { application.repositories.users.for(self) }
    var refreshTokens: RefreshTokenRepository { application.repositories.refreshTokens.for(self) }
    /// 可以使用 JWT 进行替换
    var accessTokens: AccessTokenRepository { application.repositories.accessTokens.for(self)}
    var emailTokens: EmailTokenRepository { application.repositories.emailTokens.for(self) }
    var passwordTokens: PasswordTokenRepository { application.repositories.passwordTokens.for(self) }
    
//    var email: EmailVerifier { application.emailVerifiers.verifier.for(self) }
}
