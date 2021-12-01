// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "money-backend",
    platforms: [
       .macOS(.v12)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0"),
		.package(url: "https://github.com/vapor/jwt.git", from: "4.0.0"),
		.package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
		.package(url: "https://github.com/vapor/apns.git", from: "2.0.0"),
		.package(name: "QueuesFluentDriver", url: "https://github.com/m-barthelemy/vapor-queues-fluent-driver.git", from: "1.2.0"),
		.package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0"),
		.package(url: "https://github.com/tadija/AEXML.git", from: "4.6.1")
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Vapor", package: "vapor"),
				.product(name: "JWT", package: "jwt"),
				.product(name: "Leaf", package: "leaf"),
				.product(name: "APNS", package: "apns"),
				.product(name: "QueuesFluentDriver", package: "QueuesFluentDriver"),
				.product(name: "QueuesRedisDriver", package: "queues-redis-driver"),
				.product(name: "AEXML", package: "AEXML")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
