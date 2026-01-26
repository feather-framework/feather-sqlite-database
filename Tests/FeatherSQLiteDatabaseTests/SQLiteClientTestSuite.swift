//
//  SQLiteClientTestSuite.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 26..
//

import Logging
import Testing
import FeatherDatabase
import SQLiteNIO

@testable import FeatherSQLiteDatabase

@Suite
struct SQLiteClientTestSuite {

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
            pool: .init(minimumConnections: 0, maximumConnections: 8),
            logger: logger
        )
        let client = SQLiteClient(configuration: configuration)

        try await client.run()
        defer { Task { await client.shutdown() } }

        try await closure(client)
    }

    @Test
    func concurrentTransactionsUseMultipleConnections() async throws {
        var logger = Logger(label: "test.sqlite.client")
        logger.logLevel = .info

        let configuration = SQLiteClient.Configuration(
            storage: .file(path: makeTemporaryDatabasePath()),
            pool: .init(minimumConnections: 0, maximumConnections: 2),
            logger: logger
        )
        let client = SQLiteClient(configuration: configuration)

        try await client.run()

        try await client.execute(
            query: "PRAGMA journal_mode = WAL;"
        )
        try await client.execute(
            query: #"""
                CREATE TABLE "items" (
                    "id" INTEGER NOT NULL PRIMARY KEY,
                    "name" TEXT NOT NULL
                );
                """#
        )

        async let first: Void = client.transaction { connection in
            try await connection.execute(query: "PRAGMA busy_timeout = 1000;")
            try await Task.sleep(for: .milliseconds(200))
            try await connection.execute(
                query: #"""
                    INSERT INTO "items"
                        ("id", "name")
                    VALUES
                        (1, 'alpha');
                    """#
            )
        }

        async let second: Void = client.transaction { connection in
            try await connection.execute(query: "PRAGMA busy_timeout = 1000;")
            try await Task.sleep(for: .milliseconds(200))
            try await connection.execute(
                query: #"""
                    INSERT INTO "items"
                        ("id", "name")
                    VALUES
                        (2, 'beta');
                    """#
            )
        }
        
        do {
            
            _ = try await (first, second)
            
            let result = try await client.execute(
                query: #"""
                SELECT COUNT(*) AS "count"
                FROM "items";
                """#
            )
            let rows = try await result.collect()
            
            #expect(try rows[0].decode(column: "count", as: Int.self) == 2)
            #expect(await client.connectionCount() == 2)
        }
        catch {
            Issue.record(error)
        }

        await client.shutdown()
    }

    @Test
    func concurrentTransactionUpdates() async throws {
        try await runUsingTestClient { database in
            let suffix = randomTableSuffix()
            let table = "sessions_\(suffix)"
            let sessionID = "session_\(suffix)"

            enum TestError: Error {
                case missingRow
            }

            try await database.execute(
                query: #"""
                    DROP TABLE IF EXISTS "\#(unescaped: table)";
                    """#
            )
            try await database.execute(
                query: #"""
                    CREATE TABLE "\#(unescaped: table)" (
                        "id" TEXT NOT NULL PRIMARY KEY,
                        "access_token" TEXT NOT NULL,
                        "access_expires_at" INTEGER NOT NULL,
                        "refresh_token" TEXT NOT NULL,
                        "refresh_count" INTEGER NOT NULL DEFAULT 0
                    );
                    """#
            )

            try await database.execute(
                query: #"""
                    INSERT INTO "\#(unescaped: table)"
                        ("id", "access_token", "access_expires_at", "refresh_token", "refresh_count")
                    VALUES
                        (
                            \#(sessionID),
                            'stale',
                            (strftime('%s','now') - 300),
                            'refresh',
                            0
                        );
                    """#
            )

            func getValidAccessToken(sessionID: String) async throws -> String {
                try await database.transaction { connection in
                    try await connection.execute(
                        query: "PRAGMA busy_timeout = 1000;"
                    )

                    let updateResult = try await connection.execute(
                        query: #"""
                            UPDATE "\#(unescaped: table)"
                            SET
                                "refresh_count" = "refresh_count" + 1,
                                "access_token" = 'token_' || ("refresh_count" + 1),
                                "access_expires_at" = (strftime('%s','now') + 600)
                            WHERE
                                "id" = \#(sessionID)
                                AND "access_expires_at"
                                    <= (strftime('%s','now') + 60)
                            RETURNING "access_token";
                            """#
                    )
                    let updatedRows = try await updateResult.collect()
                    if let updatedRow = updatedRows.first {
                        return try updatedRow.decode(
                            column: "access_token",
                            as: String.self
                        )
                    }

                    let result = try await connection.execute(
                        query: #"""
                            SELECT
                                "access_token",
                                "refresh_count",
                                "access_expires_at" > (strftime('%s','now') + 60) AS "is_valid"
                            FROM "\#(unescaped: table)"
                            WHERE "id" = \#(sessionID);
                            """#
                    )
                    let rows = try await result.collect()

                    guard let row = rows.first else {
                        throw TestError.missingRow
                    }

                    let isValid = try row.decode(
                        column: "is_valid",
                        as: Bool.self
                    )
                    #expect(isValid == true)

                    return try row.decode(
                        column: "access_token",
                        as: String.self
                    )
                }
            }

            let workerCount = 80
            var tokens: [String] = []
            try await withThrowingTaskGroup(of: String.self) { group in
                for _ in 0..<workerCount {
                    group.addTask {
                        try await getValidAccessToken(sessionID: sessionID)
                    }
                }
                for try await token in group {
                    tokens.append(token)
                }
            }

            #expect(Set(tokens).count == 1)

            let result =
                try await database.execute(
                    query: #"""
                        SELECT
                            "access_token",
                            "refresh_count",
                            "access_expires_at" > strftime('%s','now') AS "is_valid"
                        FROM "\#(unescaped: table)"
                        WHERE "id" = \#(sessionID);
                        """#
                )
                .collect()

            #expect(result.count == 1)
            #expect(
                try result[0].decode(column: "refresh_count", as: Int.self)
                    == 1
            )
            #expect(
                try result[0].decode(column: "access_token", as: String.self)
                    == "token_1"
            )
            #expect(
                try result[0].decode(column: "is_valid", as: Bool.self)
                    == true
            )
        }
    }
}
