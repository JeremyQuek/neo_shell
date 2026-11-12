// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "neo_shell",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", exact: "1.20.0"),
    ],
    targets: [
        .executableTarget(
            name: "neo_shell",
            dependencies: ["SwiftTerm"]
        ),
    ]
)
