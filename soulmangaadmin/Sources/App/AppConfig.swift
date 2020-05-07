//
//  AppConfig.swift
//  App
//
//  Created by Finer  Vine on 2020/5/3.
//

import Vapor

struct AppConfig {
    /// 前端链接
    let frontendURL: String
    /// api 接口
    let apiURL: String
    /// 发信人
    let noReplyEmail: String
    let noReplayEmailHostName: String
    let noReplayEmailUserName: String
    let noReplayEmailPassword: String
    
    static var environment: AppConfig {
        guard
            let frontendURL = Environment.get("SITE_FRONTEND_URL"),
            let apiURL = Environment.get("SITE_API_URL"),
            let noReplyEmail = Environment.get("NO_REPLY_EMAIL"),
            let noReplayEmailHostName = Environment.get("NO_REPLY_EMAIL_HOSTNAME"),
            let noReplayEmailUserName = Environment.get("NO_REPLY_EMAIL_USERNAME"),
            let noReplayEmailPassword = Environment.get("NO_REPLY_EMAIL_PASSWORD")
            else {
                fatalError("Please add app configuration to environment variables")
        }
        
        return .init(frontendURL: frontendURL, apiURL: apiURL, noReplyEmail: noReplyEmail, noReplayEmailHostName: noReplayEmailHostName, noReplayEmailUserName: noReplayEmailUserName, noReplayEmailPassword: noReplayEmailPassword)
    }
}

extension Application {
    struct AppConfigKey: StorageKey {
        typealias Value = AppConfig
    }
    
    var config: AppConfig {
        get {
            storage[AppConfigKey.self] ?? .environment
        }
        set {
            storage[AppConfigKey.self] = newValue
        }
    }
}

