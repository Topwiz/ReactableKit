// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "ReactableKit",
    platforms: [.iOS(.v16), .macOS(.v10_15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "ReactableKit", targets: ["ReactableKit", "DependencyInjectableKit"]),
        .library(name: "ReactableKit-Dynamic", type: .dynamic, targets: ["ReactableKit", "DependencyInjectableKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ReactableKit",
            path: "Sources/ReactableKit"
        ),
        .macro(
            name: "DependencyInjectableMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            path: "Sources/DependencyInjectableMacros"
        ),
        .target(
            name: "DependencyInjectableKit",
            dependencies: ["DependencyInjectableMacros"],
            path: "Sources/DependencyInjectableKit"
        ),
        .testTarget(
            name: "ReactableKitTests",
            dependencies: ["ReactableKit", "DependencyInjectableKit"],
            path: "Tests/ReactableKitTest"
        )
    ]
)
