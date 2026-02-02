//
//  SQLiteDatabaseClient.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 10..
//

import FeatherDatabase
import SQLiteNIO

/// A SQLite-backed database client.
///
/// Use this client to execute queries and manage transactions on SQLite.
public struct SQLiteDatabaseClient: DatabaseClient {
       
    public typealias Connection = SQLiteDatabaseConnection
    
    
    private let client: SQLiteClient

    /// Create a SQLite database client backed by a connection pool.
    ///
    /// - Parameter client: The SQLite client to use.
    public init(client: SQLiteClient) {
        self.client = client
    }

    /// Pre-open the minimum number of connections.
    public func run() async throws {
        try await client.run()
    }

    /// Close all pooled connections and refuse new leases.
    public func shutdown() async {
        await client.shutdown()
    }

    // MARK: - database api

    /// Execute work using a leased connection.
    ///
    /// The closure is executed with a pooled connection.
    /// - Parameters:
    ///   - isolation: The actor isolation to use for the closure.
    ///   - closure: A closure that receives the SQLite connection.
    /// - Throws: A `DatabaseError` if the connection fails.
    /// - Returns: The query result produced by the closure.
    @discardableResult
    public func withConnection<T>(
        _ closure: (Connection) async throws -> T
    ) async throws(DatabaseError) -> T {
        fatalError()
//        try await client.connection(isolation: isolation, closure)
    }

    /// Execute work inside a SQLite transaction.
    ///
    /// The closure runs between `BEGIN` and `COMMIT` with rollback on failure.
    /// - Parameters:
    ///   - isolation: The actor isolation to use for the closure.
    ///   - closure: A closure that receives the SQLite connection.
    /// - Throws: A `DatabaseError` if transaction handling fails.
    /// - Returns: The query result produced by the closure.
    @discardableResult
    public func withTransaction<T>(
        _ closure: (Connection) async throws -> T
    ) async throws(DatabaseError) -> T {
        fatalError()
//        try await client.transaction(isolation: isolation, closure)
    }

}
