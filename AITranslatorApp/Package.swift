// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AITranslator",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AITranslator", targets: ["AITranslator"])
    ],
    targets: [
        .executableTarget(
            name: "AITranslator",
            path: "Sources/AITranslator",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)
