//
//  BookInfo.swift
//  App
//
//  Created by Finer  Vine on 2020/4/5.
//

import Fluent
import Vapor

final class BookInfo:Model, Content {
    static let schema = "bookinfo"
    
//    @ID(key: .id)
//    var id: UUID?
    @ID(custom: "book_id")
    var id: Int?
    
    @Field(key: "book_name")
    var bookName: String
    
    @Field(key: "author_name")
    var authorName: String?
    
    // All the chapters in this BookInfo.
    @Children(for: \.$bookInfo)
    var chapters: [BookChapter]
    
    // Creates a new, empty Bookinfo.
    // Next, all models require an empty init. This allows Fluent to create new instances of the model.
    init() { }

    // Creates a new BookInfo with all properties set.
    init(id: Int? = nil, name: String, authorName: String) {
        self.id = id
        self.bookName = name
        self.authorName = authorName
    }
}
extension BookInfo: Migration {
    // Prepares the database for storing BookInfo models.
     func prepare(on database: Database) -> EventLoopFuture<Void> {
         database.schema("bookinfo")
             .field("book_id", .int, .identifier(auto: true))
             .field("book_name", .string)
             .field("author_name", .string)
             .create()
     }

     // Optionally reverts the changes made in the prepare method.
     func revert(on database: Database) -> EventLoopFuture<Void> {
         database.schema("bookinfo").delete()
     }
}
