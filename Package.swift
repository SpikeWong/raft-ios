// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RaftPersonalCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "RaftPersonal", targets: ["RaftPersonal"])],
    targets: [
        .target(name: "RaftPersonal", path: "App", exclude: ["BrowserSession.swift", "WidgetBridge.swift", "ComposerPreviewStyle.swift", "HomeTouchPolicy.swift", "ShellModel.swift", "ConnectionView.swift", "ShellView.swift", "RaftPersonalApp.swift", "Info.plist", "RaftPersonal.entitlements", "Assets.xcassets"], sources: ["URLPolicy.swift", "ConnectionStore.swift"]),
        .target(name: "RaftWidgetData", path: "Shared", exclude: ["WidgetSummaryView.swift"], sources: ["WidgetSnapshot.swift"]),
        .testTarget(name: "ConnectionTests", dependencies: ["RaftPersonal"], path: "Tests", exclude: ["WidgetSnapshotTests.swift"]),
        .testTarget(name: "WidgetSnapshotTests", dependencies: ["RaftWidgetData"], path: "Tests", exclude: ["ConnectionTests.swift"], sources: ["WidgetSnapshotTests.swift"])
    ]
)
