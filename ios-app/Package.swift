// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnonymousChat",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "AnonymousChat",
            targets: ["AnonymousChat"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AnonymousChat",
            path: "AnonymousChat"
        )
    ]
)
