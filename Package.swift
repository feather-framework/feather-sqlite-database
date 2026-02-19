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
    .enableExperimentalFeature("AvailabilityMacro=FeatherDatabaseSQLite 1.0:macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0"),
]

#if compiler(>=6.2)
defaultSwiftSettings.append(
    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
)
#endif


let package = Package(
    name: "feather-database-sqlite",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "FeatherDatabaseSQLite", targets: ["FeatherDatabaseSQLite"]),
    ],
    traits: [
        "ServiceLifecycleSupport",
        .default(
            enabledTraits: [
                "ServiceLifecycleSupport",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
        .package(url: "https://github.com/vapor/sqlite-nio", from: "1.12.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle", from: "2.8.0"),
        .package(url: "https://github.com/feather-framework/feather-database", exact: "1.0.0-beta.5"),
        // [docc-plugin-placeholder]
    ],
    targets: [
        .target(
            name: "SQLiteNIOExtras",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SQLiteNIO", package: "sqlite-nio"),
            ],
            swiftSettings: defaultSwiftSettings
        ),
        .target(
            name: "FeatherDatabaseSQLite",
            dependencies: [
                .target(name: "SQLiteNIOExtras"),
                .product(name: "FeatherDatabase", package: "feather-database"),
                .product(
                    name: "ServiceLifecycle",
                    package: "swift-service-lifecycle",
                    condition: .when(traits: ["ServiceLifecycleSupport"])
                ),
            ],
            swiftSettings: defaultSwiftSettings
        ),
        .testTarget(
            name: "SQLiteNIOExtrasTests",
            dependencies: [
                .target(name: "SQLiteNIOExtras"),
            ],
            swiftSettings: defaultSwiftSettings
        ),
        .testTarget(
            name: "FeatherDatabaseSQLiteTests",
            dependencies: [
                .target(name: "FeatherDatabaseSQLite"),
                .product(
                    name: "ServiceLifecycleTestKit",
                    package: "swift-service-lifecycle",
                    condition: .when(
                        traits: ["ServiceLifecycleSupport"]
                    )
                ),
            ],
            swiftSettings: defaultSwiftSettings
        ),
    ]
)
