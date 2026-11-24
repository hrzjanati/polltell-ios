// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PolTellCore",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: [
        .library(name: "PolTellCore", targets: ["PolTellCore"]),
        .executable(name: "poltell-vectors", targets: ["poltell-vectors"]),
        .executable(name: "poltell-central", targets: ["poltell-central"]),
    ],
    targets: [
        // libopus 1.5.2 (BSD-3-Clause), vendored, floating point, no assembly.
        .target(name: "COpus", path: "Sources/COpus", publicHeadersPath: "include",
                cSettings: [.headerSearchPath("config"), .headerSearchPath("celt"), .headerSearchPath("silk"),
                            .headerSearchPath("silk/float"), .headerSearchPath("src"),
                            .define("HAVE_CONFIG_H")]),
        .target(name: "PolTellCore", dependencies: ["COpus"]),
        .executableTarget(name: "poltell-vectors", dependencies: ["PolTellCore"]),
        // Mac test central; the embedded Info.plist carries the Bluetooth usage string TCC requires.
        .executableTarget(name: "poltell-central", dependencies: ["PolTellCore"], exclude: ["Info.plist"],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT",
                                                         "-Xlinker", "__info_plist", "-Xlinker", "Sources/poltell-central/Info.plist"])]),
        .testTarget(name: "PolTellCoreTests", dependencies: ["PolTellCore"],
                    resources: [.copy("vectors.json")]),
    ]
)
