//
//  ScheduledCrawBookJob.swift
//  App
//
//  Created by Finer  Vine on 2020/6/7.
//

import Vapor
import Fluent
import Queues
import SwiftSoup

/// 这里是定时任务
struct ScheduledCrawBookJob: ScheduledJob {
    
    static var isCrawId: Int = 0
    static var isStar: Bool = true

    func run(context: QueueContext) -> EventLoopFuture<Void> {
        // Do some work here, perhaps queue up another job.
        print("craw:\(ScheduledCrawBookJob.isCrawId)")
        if ScheduledCrawBookJob.isStar {
            return BookInfo.query(on: context.application.db)
                .all()
                .map { (infos) in
                    ScheduledCrawBookJob.isStar = false
                    if let bookId = infos.last?.id {
                        ScheduledCrawBookJob.isCrawId = bookId
                    }
                }
        }
        let bookUrlString:URI = URI(string: "https://www.52bqg.com/book_\(ScheduledCrawBookJob.isCrawId)/")
        let result = context.application.client.get(bookUrlString) { req in
            // 请求参数
        }
        .flatMapThrowing { (res: ClientResponse) -> BookInfoContext in
            // 这里是获取的内容
            let resultData = res.body.flatMap { (buffer) -> Data? in
                return buffer.getData(at: 0, length: buffer.readableBytes)
            }
            let gbk = String.Encoding(rawValue: 2147485234)
            guard let info = resultData, let infoStr = String(data: info, encoding: gbk) else {
                throw Abort(.badRequest, reason: "paser fail")
            }
            return try ScheduledCrawBookJob.paserBookInfo(pageUrl: bookUrlString.string, htmlContent: infoStr)
        }
        .flatMap { (bookInfo) -> EventLoopFuture<BookInfo> in
            // 这里进行处理
            print("bookName:\(bookInfo.bookName) chapterCount:\(bookInfo.chapters.count)")
            // 查询，如果有直接返回
            return BookInfo.query(on: context.application.db)
                .filter(\.$bookName == bookInfo.bookName)
                .all()
                .flatMap { (searchBookInfos) -> EventLoopFuture<BookInfo> in
                    // 返回查询到的
                    if searchBookInfos.count > 0 {
                        return context.eventLoop.future(searchBookInfos[0])
                    }
                    // 新建
                    let storeBookInfo = BookInfo(name: bookInfo.bookName, authorName: bookInfo.authorName)
                    return storeBookInfo.save(on: context.application.db)
                        .flatMapThrowing { (Void) -> [BookChapter] in
                            var chapters: [BookChapter] = []
                            for chapter in bookInfo.chapters {
                                let storeChapter = try BookChapter(title: chapter.title, linkUrl: chapter.linkUrl, isScraw: false, content: "", bookInfoID: storeBookInfo.requireID())
                                chapters.append(storeChapter)
                            }
                            return chapters
                    }.flatMapEach(on: context.eventLoop) { (chapter) -> EventLoopFuture<Void> in
                        chapter.save(on: context.application.db)
                    }
                    .transform(to: storeBookInfo)
            }
        }
        return result.map { _ in
            ScheduledCrawBookJob.isCrawId += 1
            return ()
        }
    }
}

extension ScheduledCrawBookJob {
    struct BookInfoContext: Content {
        struct ChapterUrlContext: Content {
            let title: String
            let linkUrl: String
        }
        
        var bookName: String
        var authorName: String
        var chapters: [ChapterUrlContext]
    }
    /// 书籍解析
    static func paserBookInfo(pageUrl: String, htmlContent: String) throws -> BookInfoContext {
        
        var bookName: String = ""
        var authorName: String = ""
        
        guard let document = try? SwiftSoup.parse(htmlContent) else { throw Abort(.badRequest, reason: "paser fail") }
        guard let box_con = try? document.select("div[class='box_con']") else { throw Abort(.badRequest, reason: "paser fail") }
        if let info = try? box_con.select("div[id='info']") {
            if let h1 = try? info.select("h1").text() {
                bookName = h1
            }
            if let p1 = try? info.select("p").get(0).text() {
                authorName = p1;
            }
        }
        var chapters: [BookInfoContext.ChapterUrlContext] = []
        guard let lists = try? box_con.select("div[id='list']").select("a") else { throw Abort(.badRequest, reason: "paser fail") }
        for link in lists {
            if let linkHref = try? link.attr("href"), let linkText = try? link.text(){
                chapters.append(.init(title: linkText, linkUrl: "\(pageUrl)\(linkHref)"))
            }
        }
        let newBookInfo = BookInfoContext(bookName: bookName, authorName: authorName, chapters: chapters)
        return newBookInfo
    }
}
