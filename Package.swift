// swift-tools-version: 5.9
import PackageDescription

// Foundation-only core tests can run on macOS without an iPhone simulator.
let package = Package(
    name: "RaftPersonalCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "RaftPersonal", targets: ["RaftPersonal"])],
    targets: [
        .target(name: "RaftPersonal", path: "App", exclude: ["BrowserSession.swift", "ShellModel.swift", "ConnectionView.swift", "ShellView.swift", "RaftPersonalApp.swift", "Info.plist", "Assets.xcassets"], sources: ["URLPolicy.swift", "ConnectionStore.swift"]),
        .testTarget(name: "ConnectionTests", dependencies: ["RaftPersonal"], path: "Tests")
    ]
)
