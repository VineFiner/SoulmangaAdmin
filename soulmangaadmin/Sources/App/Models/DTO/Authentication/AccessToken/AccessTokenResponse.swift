import Vapor

struct AccessTokenResponse: Content {
    let refreshToken: String
    let expiresIn: TimeInterval
    let accessToken: String
}
