//
//  DatabaseConnectionSQLite.swift
//  feather-database-sqlite
//
//  Created by Tibor Bödecs on 2026. 01. 10.
//

import FeatherDatabase
import Logging
import SQLiteNIO

extension DatabaseQuery {

    fileprivate struct SQLiteQuery {
        var sql: String
        var bindings: [SQLiteData]
    }

    fileprivate func toSQLiteQuery() -> SQLiteQuery {
        var sqliteSQL = sql
        var sqliteBindings: [SQLiteData] = []

        for binding in bindings {
            let idx = binding.index + 1
            sqliteSQL =
                sqliteSQL
                .replacing("{{\(idx)}}", with: "?")

            switch binding.binding {
            case .bool(let value):
                sqliteBindings.append(.integer(value ? 1 : 0))
            case .int(let value):
                sqliteBindings.append(.integer(value))
            case .double(let value):
                sqliteBindings.append(.float(value))
            case .string(let value):
                sqliteBindings.append(.text(value))
            }
        }

        return .init(
            sql: sqliteSQL,
            bindings: sqliteBindings
        )
    }
}

public struct DatabaseConnectionSQLite: DatabaseConnection {

    public typealias RowSequence = DatabaseRowSequenceSQLite

    var connection: SQLiteConnection
    public var logger: Logger

    /// Execute a SQLite query on this connection.
    ///
    /// This wraps `SQLiteNIO` query execution and maps errors.
    /// - Parameters:
    ///  - query: The SQLite query to execute.
    ///  - handler: The handler to process the result sequence.
    /// - Throws: A `DatabaseError` if the query fails.
    /// - Returns: A query result containing the returned rows.
    @discardableResult
    public func run<T: Sendable>(
        query: DatabaseQuery,
        _ handler: (RowSequence) async throws -> T = { $0 }
    ) async throws(DatabaseError) -> T {
        do {
            let sqliteQuery = query.toSQLiteQuery()
            let result = try await connection.query(
                sqliteQuery.sql,
                sqliteQuery.bindings
            )
            return try await handler(
                DatabaseRowSequenceSQLite(
                    elements: result.map {
                        .init(row: $0)
                    }
                )
            )
        }
        catch {
            throw .query(error)
        }
    }
}
