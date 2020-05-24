//
//  BookClientController.swift
//  App
//
//  Created by Finer  Vine on 2020/4/5.
//

import SwiftSoup
import Vapor
import Fluent

struct CrawClientController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let craw = routes.versioned().grouped("craw")
        
        /// 受保护的路由
        let tokenAuth = UserToken.authenticator()
        let guardTokenAuth = User.guardMiddleware()
        // token protected
        craw.group([tokenAuth, guardTokenAuth]) { (builder) in
            /// 爬取书籍 http://127.0.0.1:8080/api/craw/book/111
            builder.get("book", ":bookId", use: crawCreateBookInfo(req:))
            /// 爬取章节内容 http://127.0.0.1:8080/api/craw/chapter/09E3173B-01E7-4ACB-B465-5ED689939B33
            builder.get("chapter", ":bookId", use: crawCreateChapterInfo(req:))
            /// 写入本地 http://127.0.0.1:8080/api/craw/write?title=斩玄
            builder.get("write", use: writeLocal(req:))
        }
    }
    
    /// 创建书籍 http://127.0.0.1:8080/api/craw/book/111
    func crawCreateBookInfo(req: Request) throws ->  EventLoopFuture<BookInfo> {
        guard let bookID = req.parameters.get("bookId", as: Int.self) else {
            throw Abort(.badRequest)
        }
        let bookUrlString:URI = URI(string: "https://www.52bqg.com/book_\(bookID)/")
        let result = req.client.get(bookUrlString) { req in
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
            return try CrawClientController.paserBookInfo(pageUrl: bookUrlString.string, htmlContent: infoStr)
        }
        .flatMap { (bookInfo) -> EventLoopFuture<BookInfo> in
            // 这里进行处理
            print("bookName:\(bookInfo.bookName) chapterCount:\(bookInfo.chapters.count)")
            // 查询，如果有直接返回
            return BookInfo.query(on: req.db)
                .filter(\.$bookName == bookInfo.bookName)
                .all()
                .flatMap { (searchBookInfos) -> EventLoopFuture<BookInfo> in
                    // 返回查询到的
                    if searchBookInfos.count > 0 {
                        return req.eventLoop.future(searchBookInfos[0])
                    }
                    // 新建
                    let storeBookInfo = BookInfo(name: bookInfo.bookName, authorName: bookInfo.authorName)
                    return storeBookInfo.save(on: req.db)
                        .flatMapThrowing { (Void) -> [BookChapter] in
                            var chapters: [BookChapter] = []
                            for chapter in bookInfo.chapters {
                                let storeChapter = try BookChapter(title: chapter.title, linkUrl: chapter.linkUrl, isScraw: false, content: "", bookInfoID: storeBookInfo.requireID())
                                chapters.append(storeChapter)
                            }
                            return chapters
                    }.flatMapEach(on: req.eventLoop) { (chapter) -> EventLoopFuture<Void> in
                        chapter.save(on: req.db)
                    }
                    .transform(to: storeBookInfo)
            }
        }
        return result
    }
    /// 创建章节内容 http://127.0.0.1:8080/api/craw/chapter/AE2EEB65-1FBD-4ECD-A936-840E81B34BA5
    func crawCreateChapterInfo(req: Request) throws -> EventLoopFuture<[BookChapter]> {
        guard let bookID = req.parameters.get("bookId", as: UUID.self) else {
            throw Abort(.notFound, reason: "No poetry matched the provided id")
        }
        print("id:\(bookID)")
        // 所有等待章节
        let result = BookChapter.query(on: req.db)
            .filter(\.$bookInfo.$id == bookID)
            .filter(\.$isScraw == false)
            .range(0..<300)
            .all()
        // 进行下载
        return result.flatMapEach(on: req.eventLoop) { (chapter) -> EventLoopFuture<BookChapter> in
            self.downLoadChapter(req: req, chapter: chapter)
        }
        .flatMap({ (chapters) -> EventLoopFuture<[BookChapter]> in
            // 如果还有章节，循环下载
            if chapters.count > 0 {
                if let downloadResult = try? self.crawCreateChapterInfo(req: req) {
                    return downloadResult
                } else {
                    return req.eventLoop.future(chapters)
                }
            } else {
                return req.eventLoop.future(chapters)
            }
            
        })
    }
    // 下载，并保存章节
    func downLoadChapter(req: Request,chapter: BookChapter) -> EventLoopFuture<BookChapter> {
        let linkUrl = chapter.linkUrl
        let chapterUrl: URI = URI(string: linkUrl)
        return req.client.get(chapterUrl)
            .flatMapThrowing { (res) -> BookChapterContext in
                let resultData = res.body.flatMap { (buffer) -> Data? in
                    return buffer.getData(at: 0, length: buffer.readableBytes)
                }
                let gbk = String.Encoding(rawValue: 2147485234)
                guard let info = resultData, let infoStr = String(data: info, encoding: gbk) else {
                    throw Abort(.badRequest, reason: "paser fail")
                }
                return try CrawClientController.paserChapter(htmlContent: infoStr)
        }.flatMap { (chapterContext) -> EventLoopFuture<BookChapter> in
            chapter.content = chapterContext.content
            chapter.isScraw = true
            return chapter.save(on: req.db).transform(to: chapter)
        }
    }
}
/// 书籍信息
extension CrawClientController {
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
/// 章节信息
extension CrawClientController {
    
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

extension CrawClientController {
    // 写入本地 http://127.0.0.1:8080/api/craw/write?title=斩玄
    func writeLocal(req: Request) throws -> EventLoopFuture<BookInfo> {
        
        guard let bookTitle = req.query[String.self, at: "title"] else {
            throw Abort(.notFound, reason: "No poetry matched the provided id")
        }
        
        let directory = DirectoryConfiguration.detect()
        let workingDirectory = "\(directory.resourcesDirectory)writeTemp"
        let fm = FileManager.default
        // 当前文件，或文件夹是否存在
        if !fm.fileExists(atPath: workingDirectory) {
            // 不存在，创建文件夹
            try fm.createDirectory(atPath: workingDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        // 文件路径
        let filePath = workingDirectory + "/\(bookTitle).txt"
        // 创建文件
        if !fm.createFile(atPath: filePath, contents: nil, attributes: nil) {
            print("创建失败")
        }
        // 创建一个写文件的句柄
        let fileHandler = FileHandle(forWritingAtPath: filePath)
        
        // 这里是查询结果
        let result = BookInfo.query(on: req.db)
            .filter(\.$bookName == bookTitle)
            .with(\.$chapters)
            .first()
            .unwrap(or: Abort(.notFound))
        
        print(workingDirectory)
        return result.map { (bookInfos) -> (BookInfo) in
            let chapters = bookInfos.chapters
            chapters.forEach { (chapter) in
                let content = "《\(chapter.title)》\n\(chapter.content) \n\n"
                if let data = content.data(using: .utf8), let fileHandler = fileHandler {
                    fileHandler.write(data)
                }
            }
            return bookInfos
        }
    }
}
