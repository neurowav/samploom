// swift-tools-version: 6.0
import PackageDescription

let package: Package = .init(
    name: "SamploomDomain",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SamploomDomain", targets: ["SamploomDomain"])
    ],
    targets: [
        .target(name: "SamploomDomain"),
        .testTarget(name: "SamploomDomainTests", dependencies: ["SamploomDomain"])
    ]
)
