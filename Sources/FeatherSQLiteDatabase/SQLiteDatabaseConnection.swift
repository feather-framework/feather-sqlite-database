//
//  SQLiteConnection.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 10..
//

import FeatherDatabase
import Logging
import SQLiteNIO

public struct SQLiteDatabaseConnection: DatabaseConnection {

    public typealias Query = SQLiteDatabaseQuery
    public typealias RowSequence = SQLiteDatabaseRowSequence

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
        query: Query,
        _ handler: (RowSequence) async throws -> T = { $0 }
    ) async throws(DatabaseError) -> T {
        do {
            let result = try await connection.query(
                query.sql,
                query.bindings
            )
            return try await handler(
                SQLiteDatabaseRowSequence(
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
