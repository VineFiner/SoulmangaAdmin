import Fluent
import Vapor
import SwiftSoup

struct CrawBookInfoCommand: Command {

    struct Signature: CommandSignature {
        /*
         swift run Run craw 1 
         */
        @Argument(name: "id")
        var id: Int
    }
    /// 只读属性
    var help: String { "craw book info "}
    
    func run(using context: CommandContext, signature: Signature) throws {
        context.console.info("craw book info")
        let id = signature.id
        let craw = try crawBookInfo(client: context.application.client, database: context.application.db, bookID: id)
        let info = try craw.wait()
        print(info)
        guard let bookID = info.id else {
            return
        }
        let result = BookChapter.query(on: context.application.db)
            .filter(\.$bookInfo.$id == bookID)
            .filter(\.$isScraw == false)
            .all()
        // 进行下载
        let chapters = try result.wait()
        for chapter in chapters {
            let downChapter = try downLoadChapter(client: context.application.client, database: context.application.db, chapter: chapter).wait()
            context.console.info(downChapter.title)
        }
//        _ = try result.flatMap { (chapters) -> EventLoopFuture<[BookChapter]> in
//            chapters.map { (chapter) in
//                let downChapter = downLoadChapter(client: context.application.client, database: context.application.db, chapter: chapter)
//                _ = downChapter.map { (chapter) in
//                    context.console.info(chapter.title)
//                }
//                return downChapter
//            }.flatten(on: context.application.db.eventLoop)
//        }.wait()
        
    }

}

func crawBookInfo(client: Client, database: Database, bookID: Int) throws -> EventLoopFuture<BookInfo> {
    
    let bookUrlString:URI = URI(string: "https://www.52bqg.com/book_\(bookID)/")
    let result = client.get(bookUrlString) { req in
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
        return try paserBookInfo(pageUrl: bookUrlString.string, htmlContent: infoStr)
    }
    .flatMap { (bookInfo) -> EventLoopFuture<BookInfo> in
        // 这里进行处理
        print("bookName:\(bookInfo.bookName) chapterCount:\(bookInfo.chapters.count)")
        // 查询，如果有直接返回
        return BookInfo.query(on: database)
            .filter(\.$bookName == bookInfo.bookName)
            .all()
            .flatMap { (searchBookInfos) -> EventLoopFuture<BookInfo> in
                // 返回查询到的
                if searchBookInfos.count > 0 {
                    return database.eventLoop.future(searchBookInfos[0])
                }
                // 新建
                let storeBookInfo = BookInfo(name: bookInfo.bookName, authorName: bookInfo.authorName)
                return storeBookInfo.save(on: database)
                    .flatMapThrowing { (Void) -> [BookChapter] in
                        var chapters: [BookChapter] = []
                        for chapter in bookInfo.chapters {
                            let storeChapter = try BookChapter(title: chapter.title, linkUrl: chapter.linkUrl, isScraw: false, content: "", bookInfoID: storeBookInfo.requireID())
                            chapters.append(storeChapter)
                        }
                        return chapters
                }.flatMapEach(on: database.eventLoop) { (chapter) -> EventLoopFuture<Void> in
                    chapter.save(on: database)
                }
                .transform(to: storeBookInfo)
        }
    }
    return result
}

func paserBookInfo(pageUrl: String, htmlContent: String) throws -> BookInfoContext {
    
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

struct BookInfoContext: Content {
    struct ChapterUrlContext: Content {
        let title: String
        let linkUrl: String
    }
    
    var bookName: String
    var authorName: String
    var chapters: [ChapterUrlContext]
}

// 下载，并保存章节
 func downLoadChapter(client: Client, database: Database, chapter: BookChapter) -> EventLoopFuture<BookChapter> {
     let linkUrl = chapter.linkUrl
     let chapterUrl: URI = URI(string: linkUrl)
     return client.get(chapterUrl)
         .flatMapThrowing { (res) -> BookChapterContext in
             let resultData = res.body.flatMap { (buffer) -> Data? in
                 return buffer.getData(at: 0, length: buffer.readableBytes)
             }
             let gbk = String.Encoding(rawValue: 2147485234)
             guard let info = resultData, let infoStr = String(data: info, encoding: gbk) else {
                 throw Abort(.badRequest, reason: "paser fail")
             }
             return try paserChapter(htmlContent: infoStr)
     }.flatMap { (chapterContext) -> EventLoopFuture<BookChapter> in
         chapter.content = chapterContext.content
         chapter.isScraw = true
         return chapter.save(on: database).transform(to: chapter)
     }
 }

struct BookChapterContext: Content {
    let content: String
    let name: String
}
/// 章节信息解析
func paserChapter(htmlContent: String) throws -> BookChapterContext {
    
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
