import Vapor
import Queues

struct EmailPayload: Codable {
    let email: AnyEmail
    let recipient: String
    
    init<E: Email>(_ email: E, to recipient: String) {
        self.email = AnyEmail(email)
        self.recipient = recipient
    }
}

struct EmailJob: Job {
    typealias Payload = EmailPayload
    
    func dequeue(_ context: QueueContext, _ payload: EmailPayload) -> EventLoopFuture<Void> {
        guard let verifyUrl = payload.email.templateData["verify_url"] else {
            return context.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        context.logger.info("sending email to \(verifyUrl))")
        let url: URI = URI(string: "http://localhost:8080/api\(verifyUrl)")
        return context.application.client.get(url).transform(to: ())
    }
}
