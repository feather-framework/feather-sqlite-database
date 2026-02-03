//
//  SQLiteDatabaseClient.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 10..
//

import FeatherDatabase
import Logging
import SQLiteNIO
import SQLiteNIOExtras

/// A SQLite-backed database client.
///
/// Use this client to execute queries and manage transactions on SQLite.
public struct SQLiteDatabaseClient: DatabaseClient {

    public typealias Connection = SQLiteDatabaseConnection

    let client: SQLiteClient
    var logger: Logger

    /// Create a SQLite database client backed by a connection pool.
    ///
    /// - Parameters:
    ///  - client: The SQLite client to use.
    ///  - logger: The logger to use.
    public init(
        client: SQLiteClient,
        logger: Logger
    ) {
        self.client = client
        self.logger = logger
    }

    // MARK: - database api

    /// Execute work using a leased connection.
    ///
    /// The closure is executed with a pooled connection.
    /// - Parameters closure: A closure that receives the SQLite connection.
    /// - Throws: A `DatabaseError` if the connection fails.
    /// - Returns: The query result produced by the closure.
    @discardableResult
    public func withConnection<T>(
        _ closure: (Connection) async throws -> T
    ) async throws(DatabaseError) -> T {
        try await client.withConnection { connection in
            try await closure(
                SQLiteDatabaseConnection(
                    connection: connection,
                    logger: logger
                )
            )
        }
    }

    /// Execute work inside a SQLite transaction.
    ///
    /// The closure runs between `BEGIN` and `COMMIT` with rollback on failure.
    /// - Parameters closure: A closure that receives the SQLite connection.
    /// - Throws: A `DatabaseError` if transaction handling fails.
    /// - Returns: The query result produced by the closure.
    @discardableResult
    public func withTransaction<T>(
        _ closure: (Connection) async throws -> T
    ) async throws(DatabaseError) -> T {
        do {
            return try await client.withTransaction { connection in
                try await closure(
                    SQLiteDatabaseConnection(
                        connection: connection,
                        logger: logger
                    )
                )
            }
        }
        catch let error as SQLiteTransactionError {
            throw .transaction(
                SQLiteDatabaseTransactionError(
                    underlyingError: error
                )
            )
        }
        catch {
            throw .connection(error)
        }
    }

}
