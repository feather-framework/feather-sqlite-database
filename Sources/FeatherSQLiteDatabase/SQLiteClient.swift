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

    public typealias Connection = SQLiteConnection

    public struct Configuration: Sendable {
        public struct Pool: Sendable {
            public var minimumConnections: Int
            public var maximumConnections: Int

            public init(
                minimumConnections: Int = 0,
                maximumConnections: Int = 4
            ) {
                self.minimumConnections = minimumConnections
                self.maximumConnections = maximumConnections
            }
        }

        public var storage: SQLiteConnection.Storage
        public var pool: Pool
        public var logger: Logger

        public init(
            storage: SQLiteConnection.Storage,
            pool: Pool = .init(),
            logger: Logger = .init(label: "codes.feather.sqlite")
        ) {
            self.storage = storage
            self.pool = pool
            self.logger = logger
        }
    }

    private let pool: SQLiteConnectionPool

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
        -> SQLiteConnection {
        do {
            return try await pool.leaseConnection()
        }
        catch {
            throw .connection(error)
        }
    }
}
