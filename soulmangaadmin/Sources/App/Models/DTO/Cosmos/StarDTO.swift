//
//  StarDTO.swift
//  App
//
//  Created by Finer  Vine on 2020/5/24.
//

import Fluent
import Vapor

extension Star {
    struct Input: Content {
        let name: String
    }

    struct Output: Content {
        let id: String
        let name: String
    }
}
