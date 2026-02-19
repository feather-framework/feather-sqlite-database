//
//  SQLiteClient.swift
//  feather-database-sqlite
//
//  Created by Tibor Bödecs on 2026. 01. 26..
//

import Logging
import SQLiteNIO

/// A SQLite client backed by a connection pool.
///
/// Use this client to execute queries and transactions concurrently.
public final class SQLiteClient: Sendable {

    /// Configuration values for a pooled SQLite client.
    public struct Configuration: Sendable {

        /// SQLite journal mode options for new connections.
        public enum JournalMode: String, Sendable {
            /// Roll back changes by copying the original content.
            case delete = "DELETE"
            /// Roll back changes by truncating the rollback journal.
            case truncate = "TRUNCATE"
            /// Roll back changes by zeroing the journal header.
            case persist = "PERSIST"
            /// Keep the journal in memory.
            case memory = "MEMORY"
            /// Use write-ahead logging to improve concurrency.
            case wal = "WAL"
            /// Disable the rollback journal.
            case off = "OFF"
        }

        /// SQLite foreign key enforcement options for new connections.
        public enum ForeignKeysMode: String, Sendable {
            /// Disable foreign key enforcement.
            case off = "OFF"
            /// Enable foreign key enforcement.
            case on = "ON"
        }

        /// The SQLite storage to open connections against.
        public let storage: SQLiteConnection.Storage
        /// Minimum number of pooled connections to keep open.
        public let minimumConnections: Int
        /// Maximum number of pooled connections to allow.
        public let maximumConnections: Int
        /// Logger used for pool operations.
        public let logger: Logger
        /// Journal mode applied to each pooled connection.
        public let journalMode: JournalMode
        /// Busy timeout, in milliseconds, applied to each pooled connection.
        public let busyTimeoutMilliseconds: Int
        /// Foreign key enforcement mode applied to each pooled connection.
        public let foreignKeysMode: ForeignKeysMode

        /// Create a SQLite client configuration.
        /// - Parameters:
        ///   - storage: The SQLite storage to use.
        ///   - logger: The logger for database operations.
        ///   - minimumConnections: The minimum number of pooled connections.
        ///   - maximumConnections: The maximum number of pooled connections.
        ///   - journalMode: The journal mode to apply to connections.
        ///   - foreignKeysMode: The foreign key enforcement mode to apply.
        ///   - busyTimeoutMilliseconds: The busy timeout to apply, in milliseconds.
        public init(
            storage: SQLiteConnection.Storage,
            logger: Logger,
            minimumConnections: Int = 1,
            maximumConnections: Int = 8,
            journalMode: JournalMode = .wal,
            foreignKeysMode: ForeignKeysMode = .on,
            busyTimeoutMilliseconds: Int = 1000
        ) {
            precondition(minimumConnections >= 0)
            precondition(maximumConnections >= 1)
            precondition(minimumConnections <= maximumConnections)
            precondition(busyTimeoutMilliseconds >= 0)
            self.storage = storage
            self.minimumConnections = minimumConnections
            self.maximumConnections = maximumConnections
            self.logger = logger
            self.journalMode = journalMode
            self.foreignKeysMode = foreignKeysMode
            self.busyTimeoutMilliseconds = busyTimeoutMilliseconds
        }
    }

    private let pool: SQLiteConnectionPool

    /// Create a SQLite client with a connection pool.
    /// - Parameter configuration: The client configuration.
    public init(configuration: Configuration) {
        self.pool = SQLiteConnectionPool(
            configuration: configuration
        )
    }

    // MARK: - pool service

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
    /// - Parameter closure: A closure that receives a SQLite connection.
    /// - Throws: A `DatabaseError` if leasing or execution fails.
    /// - Returns: The result produced by the closure.
    @discardableResult
    public func withConnection<T>(
        _ closure: (SQLiteConnection) async throws -> T
    ) async throws -> T {
        let connection = try await leaseConnection()
        do {
            let result = try await closure(connection)
            await pool.releaseConnection(connection)
            return result
        }
        catch {
            await pool.releaseConnection(connection)
            throw error
        }
    }

    /// Execute work inside a SQLite transaction.
    ///
    /// The transaction is committed on success and rolled back on failure.
    /// Busy errors are retried with an exponential backoff (up to 8 attempts).
    /// - Parameters closure: A closure that receives a SQLite connection.
    /// - Throws: A `DatabaseError` if transaction handling fails.
    /// - Returns: The result produced by the closure.
    @discardableResult
    public func withTransaction<T>(
        _ closure: (SQLiteConnection) async throws -> T
    ) async throws -> T {
        let connection = try await leaseConnection()
        do {
            try await pool.leaseTransactionPermit()
        }
        catch {
            await pool.releaseConnection(connection)
            throw error
        }
        do {
            _ = try await connection.query("BEGIN;")
        }
        catch {
            await pool.releaseTransactionPermit()
            await pool.releaseConnection(connection)
            throw SQLiteTransactionError(beginError: error)
        }

        var closureHasFinished = false

        do {
            let result = try await closure(connection)
            closureHasFinished = true

            _ = try await connection.query("COMMIT;")
            await pool.releaseTransactionPermit()
            await pool.releaseConnection(connection)
            return result
        }
        catch {
            var txError = SQLiteTransactionError()

            if !closureHasFinished {
                txError.closureError = error

                do {
                    _ = try await connection.query("ROLLBACK;")
                }
                catch {
                    txError.rollbackError = error
                }
            }
            else {
                txError.commitError = error
            }

            await pool.releaseTransactionPermit()
            await pool.releaseConnection(connection)
            throw txError
        }
    }

    // MARK: - pool

    func connectionCount() async -> Int {
        await pool.connectionCount()
    }

    private func leaseConnection() async throws -> SQLiteConnection {
        try await pool.leaseConnection()
    }
}
