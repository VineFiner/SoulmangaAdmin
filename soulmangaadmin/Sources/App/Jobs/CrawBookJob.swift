//
//  CrawBookJob.swift
//  App
//
//  Created by Finer  Vine on 2020/5/31.
//

import Foundation
import Vapor
import Queues
import SwiftSoup

enum CrawError: Error {
    case noChapter
}

struct CrawBookJob: Job {
    // 有效载荷
    typealias Payload = BookChapter
    
    func dequeue(_ context: QueueContext, _ payload: BookChapter) -> EventLoopFuture<Void> {
        return self.downLoadChapter(context, chapter: payload).transform(to: ())
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: BookChapter) -> EventLoopFuture<Void> {
        // If you don't want to handle errors you can simply return a future. You can also omit this function entirely.
        // 如果您不想处理错误，则可以简单地返回未来。 您也可以完全省略此功能。
        return context.eventLoop.future()
    }
    
    // 下载，并保存章节
    func downLoadChapter(_ context: QueueContext, chapter: BookChapter) -> EventLoopFuture<BookChapter> {
        let linkUrl = chapter.linkUrl
        let chapterUrl: URI = URI(string: linkUrl)
        return context.application.client.get(chapterUrl)
            .flatMapThrowing { (res) -> BookChapterContext in
                let resultData = res.body.flatMap { (buffer) -> Data? in
                    return buffer.getData(at: 0, length: buffer.readableBytes)
                }
                let gbk = String.Encoding(rawValue: 2147485234)
                guard let info = resultData, let infoStr = String(data: info, encoding: gbk) else {
                    throw Abort(.badRequest, reason: "paser fail")
                }
                return try CrawBookJob.paserChapter(htmlContent: infoStr)
        }.flatMap { (chapterContext) -> EventLoopFuture<BookChapter> in
            chapter.content = chapterContext.content
            chapter.isScraw = true
            return chapter.save(on: context.application.db).transform(to: chapter)
        }
    }
}

extension CrawBookJob {
    struct BookChapterContext: Content {
        let content: String
        let name: String
    }
    /// 章节信息解析
    static func paserChapter(htmlContent: String) throws -> BookChapterContext {
        
        var chapterContent: String = ""
        var chapterName: String = ""
        
        guard let document = try? SwiftSoup.parse(htmlContent) else { throw Abort(.badRequest, reason: "paser fail") }
        guard let box_con = try? document.select("div[id='box_con']") else { throw Abort(.badRequest, reason: "paser fail") }
        if let content = try? box_con.select("div[id='content']").text() {
            chapterContent = content
        }
        if let bookName = try? box_con.select("div[class='bookname']").select("h1").text() {
            chapterName = bookName
        }
        return BookChapterContext(content: chapterContent, name: chapterName)
    }
}
