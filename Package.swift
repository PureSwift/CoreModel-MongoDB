// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoreModel-MongoDB",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(
            name: "MongoDBModel",
            targets: ["MongoDBModel"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/mongodb/mongo-swift-driver",
            from: "1.3.1"
        ),
        .package(
            url: "https://github.com/PureSwift/CoreModel",
            branch: "master"
        )
    ],
    targets: [
        .target(
            name: "MongoDBModel",
            dependencies: [
                "CoreModel",
                .product(
                    name: "MongoSwift",
                    package: "mongo-swift-driver"
                )
            ]
        ),
        .testTarget(
            name: "CoreModelMongoDBTests",
            dependencies: ["MongoDBModel"]
        )
    ]
)
