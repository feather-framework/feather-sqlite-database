# Feather SQLite Database

SQLite driver implementation for the abstract [Feather Database](https://github.com/feather-framework/feather-database) Swift API package.

[
    ![Release: 1.0.0-beta.2](https://img.shields.io/badge/Release-1%2E0%2E0--beta%2E2-F05138)
](
    https://github.com/feather-framework/feather-sqlite-database/releases/tag/1.0.0-beta.2
)

## Features

- 🤝 SQLite driver for Feather Database
- 😱 Automatic query parameter escaping via Swift string interpolation.
- 🔄 Async sequence query results with `Decodable` row support.
- 🧵 Designed for modern Swift concurrency
- 📚 DocC-based API Documentation
- ✅ Unit tests and code coverage

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
.package(url: "https://github.com/feather-framework/feather-sqlite-database", exact: "1.0.0-beta.2"),
```

Then add `FeatherSQLiteDatabase` to your target dependencies:

```swift
.product(name: "FeatherSQLiteDatabase", package: "feather-sqlite-database"),
```


## Usage
 
[
    ![DocC API documentation](https://img.shields.io/badge/DocC-API_documentation-F05138)
](
    https://feather-framework.github.io/feather-sqlite-database/documentation/feathersqlitedatabase/
)

API documentation is available at the following link. 

> [!TIP]
> Avoid calling `database.execute` while in a transaction; use the transaction `connection` instead.

```swift
import Logging
import SQLiteNIO
import FeatherDatabase
import FeatherSQLiteDatabase

var logger = Logger(label: "example")
logger.logLevel = .info

let connection = try await SQLiteConnection.open(
    storage: .file(path: "/Users/me/db.sqlite"),
    logger: logger
)

let database = SQLiteDatabaseClient(
    connection: connection,
    logger: logger
)

let result = try await database.execute(
    query: #"""
        SELECT 
            sqlite_version() AS "version" 
        WHERE 
            1=\#(1);
        """#
)

for try await item in result {
    let version = try item.decode(column: "version", as: String.self)
    print(version)
}

try await connection.close()
```

> [!WARNING]  
> This repository is a work in progress, things can break until it reaches v1.0.0.


## Other database drivers

The following database driver implementations are available for use:

- [Postgres](https://github.com/feather-framework/feather-postgres-database)
- [MySQL](https://github.com/feather-framework/feather-mysql-database)

## Development

- Build: `swift build`
- Test: 
    - local: `swift test`
    - using Docker: `make docker-test`
- Format: `make format`
- Check: `make check`

## Contributing

[Pull requests](https://github.com/feather-framework/feather-sqlite-database/pulls) are welcome. Please keep changes focused and include tests for new logic. 🙏
