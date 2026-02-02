//
//  SQLiteConnection.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 10..
//

import FeatherDatabase
import SQLiteNIO
import Logging

public struct SQLiteDatabaseConnection: DatabaseConnection {
    
    public typealias Query = SQLiteDatabaseQuery
    public typealias RowSequence = SQLiteDatabaseRowSequence

    var connection: SQLiteConnection
    public var logger: Logger

    /// Execute a SQLite query on this connection.
    ///
    /// This wraps `SQLiteNIO` query execution and maps errors.
    /// - Parameter query: The SQLite query to execute.
    /// - Throws: A `DatabaseError` if the query fails.
    /// - Returns: A query result containing the returned rows.
    @discardableResult
    public func run<T: Sendable>(
        query: Query,
        _ handler: (RowSequence) async throws -> T = { _ in }
    ) async throws(DatabaseError) -> T {

        let maxAttempts = 8
        var attempt = 0
        while true {
            do {
                let result = try await connection.query(
                    query.sql,
                    query.bindings
                )
                return try await handler(
                    SQLiteDatabaseRowSequence(
                        elements: result.map {
                            .init(row: $0)
                        })
                )
            }
            catch {
                attempt += 1
                if attempt >= maxAttempts {
                    throw .query(error)
                }
                let delayMilliseconds = min(1000, 25 << (attempt - 1))
                do {
                    try await Task.sleep(for: .milliseconds(delayMilliseconds))
                }
                catch {
                    throw .query(error)
                }
            }
        }
    }
}
