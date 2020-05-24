import Vapor

struct LoginResponse: Content {
    let user: UserDTO
    let accessToken: String
    let expiresIn: TimeInterval
    let refreshToken: String
}
