//
//  SQLiteConnectionPool.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 26..
//

import Logging
import SQLiteNIO

actor SQLiteConnectionPool {

    struct Configuration: Sendable {
        let storage: SQLiteConnection.Storage
        let minimumConnections: Int
        let maximumConnections: Int
        let logger: Logger

        init(
            storage: SQLiteConnection.Storage,
            minimumConnections: Int,
            maximumConnections: Int,
            logger: Logger
        ) {
            precondition(minimumConnections >= 0)
            precondition(maximumConnections >= 1)
            precondition(minimumConnections <= maximumConnections)
            self.storage = storage
            self.minimumConnections = minimumConnections
            self.maximumConnections = maximumConnections
            self.logger = logger
        }
    }

    private struct Waiter {
        let id: Int
        let continuation: CheckedContinuation<SQLiteConnection, Error>
    }

    private let configuration: Configuration
    private var availableConnections: [SQLiteConnection] = []
    private var waiters: [Waiter] = []
    private var totalConnections = 0
    private var nextWaiterID = 0
    private var isShutdown = false

    init(configuration: Configuration) {
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

    func releaseConnection(_ connection: SQLiteConnection) async {
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

    private func cancelWaiter(id: Int) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
            return
        }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func makeConnection() async throws -> SQLiteConnection {
        try await SQLiteConnection.open(
            storage: configuration.storage,
            logger: configuration.logger
        )
    }

    private func closeConnection(_ connection: SQLiteConnection) async {
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
