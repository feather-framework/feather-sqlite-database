//
//  SQLiteNIOExtrasTestSuite.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 10..
//
//
import Logging
import SQLiteNIO
import Testing

@testable import SQLiteNIOExtras

@Suite
struct SQLiteNIOExtrasTestSuite {

    private func makeTemporaryDatabasePath() -> String {
        let suffix = UInt64.random(in: 0...UInt64.max)
        return "/tmp/feather-sqlite-\(suffix).sqlite"
    }

    private func randomTableSuffix() -> String {
        String(UInt64.random(in: 0...UInt64.max))
    }

    private func runUsingTestClient(
        _ closure: (SQLiteClient) async throws -> Void
    ) async throws {
        var logger = Logger(label: "test.sqlite.client")
        logger.logLevel = .info

        let configuration = SQLiteClient.Configuration(
            storage: .file(path: makeTemporaryDatabasePath()),
            logger: logger,
        )
        let client = SQLiteClient(configuration: configuration)

        try await client.run()
        defer { Task { await client.shutdown() } }

        try await closure(client)
    }

    //    private func runUsingTestDatabaseClient(
    //        _ closure: ((SQLiteDatabaseClient) async throws -> Void)
    //    ) async throws {
    //        var logger = Logger(label: "test")
    //        logger.logLevel = .info
    //
    //        let configuration = SQLiteClient.Configuration(
    //            storage: .memory,
    //            logger: logger
    //        )
    //
    //        let client = SQLiteClient(configuration: configuration)
    //
    //        let database = SQLiteDatabaseClient(client: client)
    //
    //        try await client.run()
    //        try await closure(database)
    //        await client.shutdown()
    //    }

    @Test
    func example() async throws {

    }
}
