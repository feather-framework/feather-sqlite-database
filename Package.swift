// swift-tools-version:6.1
import PackageDescription

// NOTE: https://github.com/swift-server/swift-http-server/blob/main/Package.swift
var defaultSwiftSettings: [SwiftSetting] =
[
    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0441-formalize-language-mode-terminology.md
    .swiftLanguageMode(.v6),
    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
    .enableUpcomingFeature("MemberImportVisibility"),
    // https://forums.swift.org/t/experimental-support-for-lifetime-dependencies-in-swift-6-2-and-beyond/78638
    .enableExperimentalFeature("Lifetimes"),
    // https://github.com/swiftlang/swift/pull/65218
    .enableExperimentalFeature("AvailabilityMacro=featherSQLiteDatabase 1.0:macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0"),
]

#if compiler(>=6.2)
defaultSwiftSettings.append(
    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
)
#endif


let package = Package(
    name: "feather-sqlite-database",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "FeatherSQLiteDatabase", targets: ["FeatherSQLiteDatabase"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
        .package(url: "https://github.com/vapor/sqlite-nio", from: "1.12.0"),
        .package(url: "https://github.com/feather-framework/feather-database", branch: "feature/swift-6"),
    ],
    targets: [
        .target(
            name: "FeatherSQLiteDatabase",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SQLiteNIO", package: "sqlite-nio"),
                .product(name: "FeatherDatabase", package: "feather-database"),
            ],
            swiftSettings: defaultSwiftSettings
        ),
        .testTarget(
            name: "FeatherSQLiteDatabaseTests",
            dependencies: [
                .target(name: "FeatherSQLiteDatabase"),
            ],
            swiftSettings: defaultSwiftSettings
        ),
    ]
)
