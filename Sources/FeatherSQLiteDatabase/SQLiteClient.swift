//
//  SQLiteClient.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 26..
//

import FeatherDatabase
import Logging
import SQLiteNIO

/// A SQLite client backed by a connection pool.
///
/// Use this client to execute queries and transactions concurrently.
public final class SQLiteClient: Sendable, DatabaseClient {

    /// The SQLite connection type leased from the pool.
    public typealias Connection = SQLiteConnection

    /// Configuration options for a SQLite client.
    public struct Configuration: Sendable {
        /// Connection pool settings.
        public struct Pool: Sendable {
            /// Minimum number of pooled connections to keep open.
            public var minimumConnections: Int
            /// Maximum number of pooled connections to allow.
            public var maximumConnections: Int

            /// Create a connection pool configuration.
            /// - Parameters:
            ///   - minimumConnections: The minimum number of connections to keep open.
            ///   - maximumConnections: The maximum number of connections to allow.
            public init(
                minimumConnections: Int = 0,
                maximumConnections: Int = 4
            ) {
                self.minimumConnections = minimumConnections
                self.maximumConnections = maximumConnections
            }
        }

        /// The SQLite storage to open connections against.
        public var storage: SQLiteConnection.Storage
        /// The connection pool configuration.
        public var pool: Pool
        /// The logger used for pool operations.
        public var logger: Logger

        /// Create a SQLite client configuration.
        /// - Parameters:
        ///   - storage: The SQLite storage to use.
        ///   - pool: The pool configuration.
        ///   - logger: The logger for database operations.
        public init(
            storage: SQLiteConnection.Storage,
            pool: Pool,
            logger: Logger
        ) {
            self.storage = storage
            self.pool = pool
            self.logger = logger
        }
    }

    private let pool: SQLiteConnectionPool

    /// Create a SQLite client with a connection pool.
    /// - Parameter configuration: The client configuration.
    public init(configuration: Configuration) {
        self.pool = SQLiteConnectionPool(
            configuration: .init(
                storage: configuration.storage,
                minimumConnections: configuration.pool.minimumConnections,
                maximumConnections: configuration.pool.maximumConnections,
                logger: configuration.logger
            )
        )
    }

    /// Pre-open the minimum number of connections.
    public func run() async throws {
        try await pool.warmup()
    }

    /// Close all pooled connections and refuse new leases.
    public func shutdown() async {
        await pool.shutdown()
    }

    // MARK: - database api

    /// Execute work using a leased connection.
    ///
    /// The connection is returned to the pool when the closure completes.
    /// - Parameters:
    ///   - isolation: The actor isolation to use for the closure.
    ///   - closure: A closure that receives a SQLite connection.
    /// - Throws: A `DatabaseError` if leasing or execution fails.
    /// - Returns: The result produced by the closure.
    @discardableResult
    public func connection<T>(
        isolation: isolated (any Actor)? = #isolation,
        _ closure: (SQLiteConnection) async throws -> sending T
    ) async throws(DatabaseError) -> sending T {
        let connection = try await leaseConnection()
        do {
            let result = try await closure(connection)
            await pool.releaseConnection(connection)
            return result
        }
        catch let error as DatabaseError {
            await pool.releaseConnection(connection)
            throw error
        }
        catch {
            await pool.releaseConnection(connection)
            throw .connection(error)
        }
    }

    /// Execute work inside a SQLite transaction.
    ///
    /// The transaction is committed on success and rolled back on failure.
    /// - Parameters:
    ///   - isolation: The actor isolation to use for the closure.
    ///   - closure: A closure that receives a SQLite connection.
    /// - Throws: A `DatabaseError` if transaction handling fails.
    /// - Returns: The result produced by the closure.
    @discardableResult
    public func transaction<T>(
        isolation: isolated (any Actor)? = #isolation,
        _ closure: (SQLiteConnection) async throws -> sending T
    ) async throws(DatabaseError) -> sending T {
        let connection = try await leaseConnection()
        do {
            try await connection.execute(query: "BEGIN;")
        }
        catch {
            await pool.releaseConnection(connection)
            throw DatabaseError.transaction(
                SQLiteTransactionError(beginError: error)
            )
        }

        var closureHasFinished = false

        do {
            let result = try await closure(connection)
            closureHasFinished = true

            do {
                try await connection.execute(query: "COMMIT;")
            }
            catch {
                await pool.releaseConnection(connection)
                throw DatabaseError.transaction(
                    SQLiteTransactionError(commitError: error)
                )
            }

            await pool.releaseConnection(connection)
            return result
        }
        catch {
            var txError = SQLiteTransactionError()

            if !closureHasFinished {
                txError.closureError = error

                do {
                    try await connection.execute(query: "ROLLBACK;")
                }
                catch {
                    txError.rollbackError = error
                }
            }
            else {
                txError.commitError = error
            }

            await pool.releaseConnection(connection)
            throw DatabaseError.transaction(txError)
        }
    }

    func connectionCount() async -> Int {
        await pool.connectionCount()
    }

    private func leaseConnection() async throws(DatabaseError)
        -> SQLiteConnection
    {
        do {
            return try await pool.leaseConnection()
        }
        catch {
            throw .connection(error)
        }
    }
}
