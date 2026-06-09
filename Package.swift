// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftGameplayTag",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "SwiftGameplayTag", targets: ["SwiftGameplayTag"])
    ],
    targets: [
        .executableTarget(
            name: "SwiftGameplayTag",
            path: "Sources/SwiftGameplayTag"
        ),
        .testTarget(
            name: "SwiftGameplayTagTests",
            dependencies: ["SwiftGameplayTag"],
            path: "Tests/SwiftGameplayTagTests"
        )
    ]
)
