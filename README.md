# Feather Database SQLite

SQLite driver implementation for the abstract [Feather Database](https://github.com/feather-framework/feather-database) Swift API package.

[
    ![Release: 1.0.0-beta.8](https://img.shields.io/badge/Release-1%2E0%2E0--beta%2E8-F05138)
](
    https://github.com/feather-framework/feather-database-sqlite/releases/tag/1.0.0-beta.8
)

## Features

- SQLite driver for Feather Database
- Automatic query parameter escaping via Swift string interpolation.
- Async sequence query results with `Decodable` row support.
- Designed for modern Swift concurrency
- DocC-based API Documentation
- Unit tests and code coverage

## Requirements

![Swift 6.1+](https://img.shields.io/badge/Swift-6%2E1%2B-F05138)
![Platforms: Linux, macOS, iOS, tvOS, watchOS, visionOS](https://img.shields.io/badge/Platforms-Linux_%7C_macOS_%7C_iOS_%7C_tvOS_%7C_watchOS_%7C_visionOS-F05138)

- Swift 6.1+
- Platforms:
  - Linux
  - macOS 15+
  - iOS 18+
  - tvOS 18+
  - watchOS 11+
  - visionOS 2+

## Installation

Add the dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/feather-framework/feather-database-sqlite", exact: "1.0.0-beta.8"),
```

Then add `FeatherDatabaseSQLite` to your target dependencies:

```swift
.product(name: "FeatherDatabaseSQLite", package: "feather-database-sqlite"),
```

### Package traits

This package offers additional integrations you can enable using [package traits](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/addingdependencies#Packages-with-Traits).
To enable an additional trait on the package, update the package dependency:

```diff
.package(
    url: "https://github.com/feather-framework/feather-database-sqlite",
    exact: "1.0.0-beta.8",
+   traits: [
+       .defaults, 
+       "ServiceLifecycleSupport",
+   ]
)
```

Available traits:

- `ServiceLifecycleSupport` (default): Adds support for `DatabaseServiceSQLite`, a `ServiceLifecycle.Service` implementation for managing SQLite clients.


## Usage

API documentation is available at the link below:

[
    ![DocC API documentation](https://img.shields.io/badge/DocC-API_documentation-F05138)
](
    https://feather-framework.github.io/feather-database-sqlite/
)

Here is a brief example:  

```swift
import Logging
import SQLiteNIO
import SQLiteNIOExtras
import FeatherDatabase
import FeatherDatabaseSQLite

var logger = Logger(label: "example")
logger.logLevel = .info

let configuration = SQLiteClient.Configuration(
    storage: .file(path: "/Users/me/db.sqlite"),
    logger: logger
)

let client = SQLiteClient(configuration: configuration)

let database = DatabaseClientSQLite(
    client: client,
    logger: logger
)

try await client.run()

let result = try await database.withConnection { connection in
    try await connection.run(
        query: #"""
            SELECT
                sqlite_version() AS "version"
            WHERE
                1=\#(1);
            """#
    )
}

for try await item in result {
    let version = try item.decode(column: "version", as: String.self)
    print(version)
}

await client.shutdown()
```

> [!WARNING]  
> This repository is a work in progress, things can break until it reaches v1.0.0.

## Other database drivers

The following database driver implementations are available for use:

- [Postgres](https://github.com/feather-framework/feather-database-postgres)
- [MySQL](https://github.com/feather-framework/feather-database-mysql)

## Development

- Build: `swift build`
- Test:
  - local: `swift test`
  - using Docker: `make docker-test`
- Format: `make format`
- Check: `make check`

## Contributing

[Pull requests](https://github.com/feather-framework/feather-database-sqlite/pulls) are welcome. Please keep changes focused and include tests for new logic.
