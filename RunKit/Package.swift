// swift-tools-version: 6.2
import PackageDescription

// Pure logic for the app: program data, run engine, coach rules, calculations, GPS math, storage.
// No UIKit or SwiftUI here, so everything tests on the Mac with `swift test`.
let package = Package(
    name: "RunKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "RunKit", targets: ["RunKit"])
    ],
    targets: [
        .target(name: "RunKit"),
        .testTarget(name: "RunKitTests", dependencies: ["RunKit"]),
    ]
)
