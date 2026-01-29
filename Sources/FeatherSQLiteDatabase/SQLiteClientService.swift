//
//  SQLiteClientService.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 29..
//

#if ServiceLifecycleSupport
import ServiceLifecycle

/// A `Service` wrapper around an `SQLiteClient`.
public struct SQLiteClientService: Service {

    /// The underlying SQLite client instance.
    public var sqliteClient: SQLiteClient

    /// Creates a new SQLite client service.
    ///
    /// - Parameter sqliteClient: The SQLite client to manage for the service lifecycle.
    public init(sqliteClient: SQLiteClient) {
        self.sqliteClient = sqliteClient
    }

    /// Runs the SQLite client service.
    ///
    /// This method starts the SQLite client, waits for a graceful shutdown
    /// signal, and then shuts down the client in an orderly manner.
    ///
    /// - Throws: Rethrows any error produced while starting the SQLite client.
    public func run() async throws {
        try await sqliteClient.run()
        try? await gracefulShutdown()
        await sqliteClient.shutdown()
    }

}
#endif
