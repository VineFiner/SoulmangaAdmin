import Vapor
import Queues
import SwiftSMTPVapor

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
        /*
        guard let verifyUrl = payload.email.templateData["verify_url"] else {
            return context.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        context.logger.info("sending email to \(verifyUrl))")
        let url: URI = URI(string: "http://localhost:8080/api\(verifyUrl)")
        return context.application.client.get(url).transform(to: ())
        */
        
        let info = payload.email.templateData.map { (key: String, value: String) -> String in
            return "\(key): \(value)"
        }.joined(separator: "")
        
        let message = SwiftSMTPVapor.Email.init(
            sender: .init(emailAddress: context.application.config.noReplyEmail),
            recipients: [.init(emailAddress: payload.recipient)],
            subject: payload.email.subject,
            body: .universal(plain: payload.email.templateName, html: info))
        return context.application.swiftSMTP.mailer.send(email: message).transform(to: ())
    }
}
