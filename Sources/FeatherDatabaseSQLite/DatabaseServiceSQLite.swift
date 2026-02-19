//
//  DatabaseServiceSQLite.swift
//  feather-database-sqlite
//
//  Created by Tibor Bödecs on 2026. 01. 29..
//

#if ServiceLifecycleSupport

import SQLiteNIOExtras
import ServiceLifecycle

/// A `Service` wrapper around an `SQLiteClient`.
public struct DatabaseServiceSQLite: Service {

    /// The underlying SQLite client instance.
    public var client: SQLiteClient

    /// Creates a new SQLite client service.
    ///
    /// - Parameter client: The SQLite client to manage for the service lifecycle.
    public init(
        _ client: SQLiteClient
    ) {
        self.client = client
    }

    /// Runs the SQLite client service.
    ///
    /// This method starts the SQLite client, waits for a graceful shutdown
    /// signal, and then shuts down the client in an orderly manner.
    ///
    /// - Throws: Rethrows any error produced while starting the SQLite client.
    public func run() async throws {
        do {
            try await client.run()
            try? await gracefulShutdown()
            await client.shutdown()
        }
        catch {
            await client.shutdown()
            throw error
        }

    }

}
#endif
