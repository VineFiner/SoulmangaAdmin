//
//  BookChapter.swift
//  App
//
//  Created by Finer  Vine on 2020/4/5.
//

import Fluent
import Vapor

final class BookChapter: Model, Content {
    static let schema = "bookChapter"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "title")
    var title: String

    @Field(key: "link_url")
    var linkUrl: String
    
    @Field(key: "scraw_status")
    var isScraw: Bool
    
    @Field(key: "content")
    var content: String
    
    // Reference to the BookInfo this Chapter is in.
    @Parent(key: "bookinfo_id")
    var bookInfo: BookInfo
    
    // Creates a new, empty Chapter.
    init() { }
    
    // Creates a new chapter with all properties set.
    init(id: UUID? = nil, title: String, linkUrl: String, isScraw: Bool,content: String, bookInfoID: UUID) {
        self.id = id
        self.title = title
        self.linkUrl = linkUrl
        self.isScraw = isScraw
        self.content = content
        self.$bookInfo.id = bookInfoID
    }
}
extension BookChapter: Migration {
    // Prepares the database for storing Star models.
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("bookChapter")
            .id()
            .field("title", .string)
            .field("link_url", .string)
            .field("scraw_status", .bool)
            .field("content", .string)
            // This field specifies an optional constraint telling the database that the field's value references the field "id" in the "bookinfo" schema. This is also known as a foreign key and helps ensure data integrity.
            .field("bookinfo_id", .int, .references("bookinfo", "id"))
            .create()
    }

    // Optionally reverts the changes made in the prepare method.
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("bookChapter").delete()
    }
}

extension BookChapter {
    struct Public: Content {
        let id: UUID?
        let title: String
        let content: String
    }
    
    func convertToPublic() -> BookChapter.Public {
        return BookChapter.Public(id: id, title: title, content: content)
    }
}
