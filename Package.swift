// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BroClean",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "broclean", targets: ["BroCleanCLI"]),
        .executable(name: "BroCleanDesktop", targets: ["BrowserScopeApp"]),
        .executable(name: "browser-scope-diagnostics", targets: ["BrowserScopeDiagnostics"]),
        .library(name: "BrowserScopeCore", targets: ["BrowserScopeCore"])
    ],
    targets: [
        .target(name: "BroCleanCLIKit", dependencies: ["BrowserScopeCore"]),
        .executableTarget(name: "BroCleanCLI", dependencies: ["BroCleanCLIKit", "BrowserScopeCore"]),
        .testTarget(name: "BroCleanCLIKitTests", dependencies: ["BroCleanCLIKit", "BrowserScopeCore"]),
        .target(name: "CProcess", publicHeadersPath: "include"),
        .target(name: "BrowserScopeCore", dependencies: ["CProcess"]),
        .executableTarget(name: "BrowserScopeApp", dependencies: ["BrowserScopeCore"], resources: [.process("Resources")]),
        .executableTarget(name: "BrowserScopeDiagnostics", dependencies: ["BrowserScopeCore"]),
        .testTarget(name: "BrowserScopeCoreTests", dependencies: ["BrowserScopeCore"])
    ],
    swiftLanguageModes: [.v6]
)
