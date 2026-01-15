# FeatherSQLiteDatabase

SQLite driver for the abstract feather-database component for Feather CMS.

## Getting started

⚠️ This repository is a work in progress, things can break until it reaches v1.0.0. 

Use at your own risk.

### Adding the dependency

To add a dependency on the package, declare it in your `Package.swift`:

```swift
.package(url: "https://github.com/feather-framework/feather-sqlite-database", from: "1.0.0-beta.1"),
```

and to your application target, add `FeatherSQLDatabase` to your dependencies:

```swift
.product(name: "FeatherSQLiteDatabase", package: "feather-sqlite-database")
```

Example `Package.swift` file with `FeatherDatabaseDriverSQLite` as a dependency:

```swift
// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "my-application",
    dependencies: [
        .package(url: "https://github.com/feather-framework/feather-sqlite-database", from: "1.0.0-beta.1"),
    ],
    targets: [
        .target(name: "MyApplication", dependencies: [
            .product(name: "FeatherSQLiteDatabase", package: "feather-sqlite-database")
        ]),
        .testTarget(name: "MyApplicationTests", dependencies: [
            .target(name: "MyApplication"),
        ]),
    ]
)
```

