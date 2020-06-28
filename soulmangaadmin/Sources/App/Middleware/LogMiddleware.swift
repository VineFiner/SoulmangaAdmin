import Vapor

final class LogMiddleware: Middleware {
    
    // 创建一个存储属性来保存 Logger
    let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    // 实现 MIddleware 协议
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // 打印请求的描述
        let reqInfo = "\(String(describing: request.remoteAddress?.hostname)) \(request.method.string) \(request.url.path)"
        logger.info(Logger.Message.init(stringLiteral: reqInfo))
        //“Forward the incoming request to the next responder.”
        // 将传入的请求转发的下一个响应者
        return next.respond(to: request)
    }
}
