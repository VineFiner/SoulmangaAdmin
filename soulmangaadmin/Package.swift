// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "soulmangaadmin",
    platforms: [
       .macOS(.v10_15)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0-rc"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0-rc"),
        .package(url: "https://github.com/vapor/queues.git", from: "1.0.0-rc"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0-rc"),

        // develop
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0-rc")
    ],
    targets: [
        .target(name: "QueueMemoryDriver",dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Queues", package: "queues")
            ]
        ),
        .target(name: "App", dependencies: [
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
            .product(name: "Vapor", package: "vapor"),
            .product(name: "Queues", package: "queues"),
            .product(name: "Leaf", package: "leaf"),
            
            // develop
            .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
            "QueueMemoryDriver"
        ]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
