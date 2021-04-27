// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoopOnboarding",
    defaultLocalization: "en",
    platforms: [.iOS(.v13), .watchOS(.v4)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(name: "LoopOnboardingKitUI", targets: ["LoopOnboardingKitUI"]),
        .library(name: "LoopOnboardingPlugin", targets: ["LoopOnboardingPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/LoopKit/LoopKit.git", .branch("package-experiment2"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LoopOnboardingKitUI",
            dependencies: [
                "LoopKit",
                .product(name: "LoopKitUI", package: "LoopKit")
            ],
            exclude: ["Info.plist"]
        ),
        .target(
            name: "LoopOnboardingPlugin",
            dependencies: [
                "LoopKit",
                .product(name: "LoopKitUI", package: "LoopKit"),
                "LoopOnboardingKitUI"
            ],
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "LoopOnboardingKitTests",
            dependencies: ["LoopKit"],
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "LoopOnboardingKitUITests",
            dependencies: ["LoopKit"],
            exclude: ["Info.plist"]
        ),
    ]
)
