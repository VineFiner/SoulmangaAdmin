//
//  GalaxyDTO.swift
//  App
//
//  Created by Finer  Vine on 2020/5/18.
//

import Fluent
import Vapor

extension Galaxy {
    struct Input: Content {
        let name: String
    }

    struct Output: Content {
        let id: String
        let name: String
    }
}
