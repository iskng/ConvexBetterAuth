// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConvexBetterAuth",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "ConvexBetterAuth", targets: ["ConvexBetterAuth"]) 
    ],
    dependencies: [
        .package(url: "https://github.com/iskng/BetterAuthSwift.git", from: "0.1.0"),
        .package(url: "https://github.com/get-convex/convex-swift", from: "0.5.5")
    ],
    targets: [
        .target(name: "ConvexBetterAuth", dependencies: [
            .product(name: "BetterAuthSwift", package: "BetterAuthSwift"),
            .product(name: "ConvexMobile", package: "convex-swift", condition: .when(platforms: [.iOS, .macOS]))
        ]),
        .testTarget(name: "ConvexBetterAuthTests", dependencies: [
            "ConvexBetterAuth",
            .product(name: "BetterAuthSwift", package: "BetterAuthSwift")
        ])
    ]
)
