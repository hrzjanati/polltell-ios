// swift-tools-version:5.9
// The PolTell Swift SDK: protocol, crypto, framing, messages, audio (Opus, playout) and, on Apple platforms, the
// CoreBluetooth client link. Add it to a package with
//
//     .package(url: "https://github.com/hrzjanati/polltell-ios", branch: "main")
//
// and depend on the "PolTellCore" product. The sources live in ios/PolTellCore, which is also a package of its own
// (the iPhone app uses that one as a local package); both manifests build the same files. Guide: docs/SDK-swift.md.
import Foundation
import PackageDescription

let core = "ios/PolTellCore/Sources"
/// libopus's internal headers (everything outside include/). They stay on disk for its own `#include`s; leaving them
/// out of the target keeps them out of the documentation's symbol extraction, where many do not compile on their own.
let opusPrivateHeaders = (FileManager.default.enumerator(atPath: Context.packageDirectory + "/\(core)/COpus")?
    .allObjects as? [String] ?? []).filter { $0.hasSuffix(".h") && !$0.hasPrefix("include/") }.sorted()
/// Platforms without CryptoKit get the same API from swift-crypto.
let nonApple: [Platform] = [.linux, .android, .windows, .wasi]

let package = Package(
    name: "PolTell",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "PolTellCore", targets: ["PolTellCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"6.0.0"),
        // Documentation only: `swift package generate-documentation --target PolTellCore`.
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        // libopus 1.5.2 (BSD-3-Clause), vendored, floating point, no assembly.
        .target(name: "COpus", path: "\(core)/COpus", exclude: ["COPYING", ".gitattributes"] + opusPrivateHeaders, publicHeadersPath: "include",
                cSettings: [.headerSearchPath("config"), .headerSearchPath("celt"), .headerSearchPath("silk"),
                            .headerSearchPath("silk/float"), .headerSearchPath("src"),
                            .define("HAVE_CONFIG_H")],
                linkerSettings: [.linkedLibrary("m", .when(platforms: [.linux, .android]))]),
        .target(name: "PolTellCore",
                dependencies: ["COpus",
                               .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: nonApple))],
                path: "\(core)/PolTellCore"),
        .testTarget(name: "PolTellCoreTests",
                    dependencies: ["PolTellCore",
                                   .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: nonApple))],
                    path: "ios/PolTellCore/Tests/PolTellCoreTests",
                    resources: [.copy("vectors.json")]),
    ]
)
