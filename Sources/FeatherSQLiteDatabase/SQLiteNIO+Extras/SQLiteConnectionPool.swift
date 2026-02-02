//
//  SQLiteConnectionPool.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 26..
//

import Logging
import SQLiteNIO

enum SQLiteConnectionPoolError: Error, Sendable {
    case shutdown
}

actor SQLiteDatabaseConnectionPool {

    private struct Waiter {
        let id: Int
        let continuation: CheckedContinuation<SQLiteConnection, Error>
    }

    private let configuration: SQLiteClient.Configuration
    private var availableConnections: [SQLiteConnection] = []
    private var waiters: [Waiter] = []
    private var totalConnections = 0
    private var nextWaiterID = 0
    private var isShutdown = false

    init(
        configuration: SQLiteClient.Configuration
    ) {
        self.configuration = configuration
    }

    func warmup() async throws {
        guard !isShutdown else { return }
        let target = configuration.minimumConnections
        guard totalConnections < target else { return }
        let newConnections = target - totalConnections
        for _ in 0..<newConnections {
            let connection = try await makeConnection()
            availableConnections.append(connection)
            totalConnections += 1
        }
    }

    func leaseConnection() async throws -> SQLiteConnection {
        guard !isShutdown else {
            throw SQLiteConnectionPoolError.shutdown
        }

        if let connection = availableConnections.popLast() {
            return connection
        }

        if totalConnections < configuration.maximumConnections {
            totalConnections += 1
            do {
                return try await makeConnection()
            }
            catch {
                totalConnections -= 1
                throw error
            }
        }

        let waiterID = nextWaiterID
        nextWaiterID += 1

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(
                    Waiter(id: waiterID, continuation: continuation)
                )
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: waiterID) }
        }
    }

    func releaseConnection(
        _ connection: SQLiteConnection
    ) async {
        if isShutdown {
            await closeConnection(connection)
            return
        }

        if waiters.isEmpty {
            availableConnections.append(connection)
            return
        }

        let waiter = waiters.removeFirst()
        waiter.continuation.resume(returning: connection)
    }

    func shutdown() async {
        guard !isShutdown else { return }
        isShutdown = true

        let connections = availableConnections
        availableConnections.removeAll(keepingCapacity: false)

        for connection in connections {
            await closeConnection(connection)
        }

        for waiter in waiters {
            waiter.continuation.resume(
                throwing: SQLiteConnectionPoolError.shutdown
            )
        }
        waiters.removeAll(keepingCapacity: false)
    }

    func connectionCount() -> Int {
        totalConnections
    }

    private func cancelWaiter(
        id: Int
    ) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
            return
        }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func makeConnection() async throws -> SQLiteConnection {
        let connection = try await SQLiteConnection.open(
            storage: configuration.storage,
            logger: configuration.logger
        )
        do {
//            _ = try await connection.execute(
//                query:
//                    "PRAGMA journal_mode = \(unescaped: configuration.journalMode.rawValue);"
//            )
//            _ = try await connection.execute(
//                query:
//                    "PRAGMA busy_timeout = \(unescaped: String(configuration.busyTimeoutMilliseconds));"
//            )
//            _ = try await connection.execute(
//                query:
//                    "PRAGMA foreign_keys = \(unescaped: configuration.foreignKeysMode.rawValue);"
//            )
        }
        catch {
            do {
                try await connection.close()
            }
            catch {
                configuration.logger.warning(
                    "Failed to close SQLite connection after setup error",
                    metadata: ["error": "\(error)"]
                )
            }
            throw error
        }
        return connection
    }

    private func closeConnection(
        _ connection: SQLiteConnection
    ) async {
        do {
            try await connection.close()
        }
        catch {
            configuration.logger.warning(
                "Failed to close SQLite connection",
                metadata: ["error": "\(error)"]
            )
        }
    }
}
