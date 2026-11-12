// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MatrixTerm",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", exact: "1.20.0"),
    ],
    targets: [
        .executableTarget(
            name: "MatrixTerm",
            dependencies: ["SwiftTerm"]
        ),
    ]
)
