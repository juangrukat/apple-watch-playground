// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "WatchPlayground", platforms: [.macOS(.v14)], products: [.executable(name: "WatchPlayground", targets: ["WatchPlayground"])], targets: [.executableTarget(name: "WatchPlayground", swiftSettings: [.swiftLanguageMode(.v5)])])
