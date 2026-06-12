// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "SnapTranslateCN",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SnapTranslate",
            path: "Sources/SnapTranslate",
            exclude: ["Resources/Info.plist"]
        ),
        .testTarget(
            name: "SnapTranslateTests",
            dependencies: ["SnapTranslate"],
            path: "Tests/SnapTranslateTests"
        )
    ]
)
