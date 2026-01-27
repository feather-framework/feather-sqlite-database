//
//  SQLiteConnection.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 10..
//

import FeatherDatabase
import SQLiteNIO

extension SQLiteConnection: @retroactive DatabaseConnection {

    /// Execute a SQLite query on this connection.
    ///
    /// This wraps `SQLiteNIO` query execution and maps errors.
    /// - Parameter query: The SQLite query to execute.
    /// - Throws: A `DatabaseError` if the query fails.
    /// - Returns: A query result containing the returned rows.
    @discardableResult
    public func execute(
        query: SQLiteQuery
    ) async throws(DatabaseError) -> SQLiteQueryResult {
        let maxAttempts = 8
        var attempt = 0

        while true {
            do {
                let result = try await self.query(
                    query.sql,
                    query.bindings
                )
                return SQLiteQueryResult(elements: result)
            }
            catch {
                attempt += 1

                if attempt >= maxAttempts || !isBusyError(error) {
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

    private func isBusyError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("database is locked") || message.contains("busy")
    }
}
