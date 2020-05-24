//
//  BookController.swift
//  App
//
//  Created by Finer  Vine on 2020/4/5.
//

import Vapor
import Fluent

struct BookController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        
        let api = routes.versioned().grouped("book")
        
        /// 受保护的路由
        let tokenAuth = UserToken.authenticator()
        let guardTokenAuth = User.guardMiddleware()
        // token protected
        api.group([tokenAuth, guardTokenAuth]) { (builder) in
            /// 创建书籍
            builder.post("createBookInfo", use: createBookInfo)
            /// 创建章节
            builder.post("createChapter", use: createBookChapter)
            /// 获取书籍
            builder.get("bookInfos", use: getBookInfo)
            /// 获取 书籍 章节
            builder.get("bookWithChapters", use: getBookInfoAndChapters)
        }
        
        /****************未受保护的路由****************/
        /// 搜索单本书籍
        api.get("searchBookWithChapters", use: searchBookInfoWithChapters)
        /// 依据书名， 搜索章节
        api.get("searchChapters", use: searchChaptersWithBookName)
    }
    /// 创建书籍 http://127.0.0.1:8080/api/book/createBookInfo
    /*
     curl -H "Content-Type:application/json" \
     -X POST \
     -d '{
     "bookName": "VapNovelor"
     }' \
     http://127.0.0.1:8080/api/book/createBookInfo
     */
    func createBookInfo(req: Request) throws -> EventLoopFuture<BookInfo> {
        let bookInfo = try req.content.decode(BookInfo.self)
        return bookInfo.create(on: req.db).map { bookInfo }
    }
    /// 获取书籍  http://127.0.0.1:8080/api/book/bookInfos
    func getBookInfo(req: Request) throws -> EventLoopFuture<[BookInfo]> {
        return BookInfo.query(on: req.db).all()
    }
    /// 创建章节 http://127.0.0.1:8080/api/book/createChapter
    /*
     curl -H "Content-Type:application/json" \
     -X POST \
     -d '{
     "title": "标题",
     "link_url": "链接url",
     "content": "内容",
     "bookInfo": {
     "id": 1
     }
     }' \
     http://127.0.0.1:8080/api/book/createChapter
     */
    func createBookChapter(req: Request) throws -> EventLoopFuture<BookChapter> {
        let chapter = try req.content.decode(BookChapter.self)
        return chapter.create(on: req.db)
            .map { chapter }
    }
    /// 返回所有书籍 http://127.0.0.1:8080/api/book/bookAndChapters
    func getBookInfoAndChapters(req: Request) throws -> EventLoopFuture<[BookInfo]> {
        return BookInfo.query(on: req.db).with(\.$chapters).all()
    }
    /// 搜索书籍 http://127.0.0.1:8080/api/book/searchBookWithChapters?title=斩玄
    func searchBookInfoWithChapters(req: Request) throws -> EventLoopFuture<FormatSearchBook> {
        guard let bookTitle = req.query[String.self, at: "title"] else {
            throw Abort(.notFound, reason: "No poetry matched the provided id")
        }
        #if false
        /// 查询书籍
        let bookInfo = BookInfo.query(on: req.db)
            .filter(\.$bookName == bookTitle)
            .join(BookChapter.self, on: \BookInfo.$id == \BookChapter.$bookInfo.$id)
            .all()
        return bookInfo.flatMapThrowing { (items) -> FormatSearchBook in
            guard let info = items.first else {
                throw Abort(.notFound)
            }
            var chapters = [BookChapter]()
            for item in items {
                chapters.append(try item.joined(BookChapter.self))
            }
            return FormatSearchBook(bookInfo: info, chapters: chapters)
        }
        #else
        /// 查询章节
        let chapters = BookChapter.query(on: req.db)
            .join(BookInfo.self, on: \BookChapter.$bookInfo.$id == \BookInfo.$id)
            .filter(BookInfo.self, \.$bookName == bookTitle)
            .paginate(for: req)
        return chapters.flatMapThrowing { (page) -> FormatSearchBook in
            guard let first = page.items.first,
                let info = try? first.joined(BookInfo.self) else {
                    throw Abort(.notFound)
            }
            return FormatSearchBook(bookInfo: info, chapters: page.items, metadata: page.metadata)
        }
        #endif
    }
    /// 搜索章节 http://127.0.0.1:8080/api/book/searchChapters?page=1&per=10&title=斩玄
    func searchChaptersWithBookName(req: Request) throws -> EventLoopFuture<Page<BookChapter>> {
        guard let bookTitle = req.query[String.self, at: "title"] else {
            throw Abort(.notFound, reason: "No poetry matched the provided id")
        }
        return BookChapter.query(on: req.db)
            .join(BookInfo.self, on: \BookChapter.$bookInfo.$id == \BookInfo.$id)
            .filter(BookInfo.self, \.$bookName == bookTitle)
            .paginate(for: req)
    }
}

extension BookController {
    struct FormatSearchBook: Content {
        let bookInfo: BookInfo
        let chapters: [BookChapter]
        let metadata: PageMetadata
    }
}
