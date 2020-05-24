//
//  StarTag.swift
//  App
//
//  Created by Finer  Vine on 2020/5/24.
//
import Foundation
import Fluent

final class StarTag: Model {
    // Name of the table or collection.
    static let schema: String = "star_tag"

    // Unique identifier for this pivot.
    @ID(key: .id)
    var id: UUID?

    // Reference to the Tag this pivot relates.
    @Parent(key: "tag_id")
    var tag: Tag

    // Reference to the Star this pivot relates.
    @Parent(key: "star_id")
    var star: Star

    // Creates a new, empty pivot.
    init() {}

    // Creates a new pivot with all properties set.
    init(tagID: UUID, starID: UUID) {
        self.$tag.id = tagID
        self.$star.id = starID
    }

}
