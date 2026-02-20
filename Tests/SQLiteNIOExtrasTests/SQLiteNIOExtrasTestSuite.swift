//
//  SQLiteNIOExtrasTestSuite.swift
//  feather-database-sqlite
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

    @Test
    func concurrentTransactionsUseMultipleConnections() async throws {
        try await runUsingTestClient { client in

            try await client.withConnection { connection in

                try await connection.query(
                    #"""
                    CREATE TABLE "items" (
                        "id" INTEGER NOT NULL PRIMARY KEY,
                        "name" TEXT NOT NULL
                    );
                    """#
                )
            }

            async let first = client.withTransaction { connection in
                try await connection.query(
                    #"""
                    INSERT INTO "items"
                        ("id", "name")
                    VALUES
                        (1, 'alpha');
                    """#
                )
            }

            async let second = client.withTransaction { connection in
                try await connection.query(
                    #"""
                    INSERT INTO "items"
                        ("id", "name")
                    VALUES
                        (2, 'beta');
                    """#
                )
            }

            do {
                _ = try await (first, second)

                let rows = try await client.withConnection { connection in
                    try await connection.query(
                        #"""
                        SELECT COUNT(*) AS "count"
                        FROM "items";
                        """#
                    )
                }
                #expect(rows.count == 1)
                #expect(rows[0].column("count")?.integer == 2)

                #expect(await client.connectionCount() == 2)
            }
            catch {
                Issue.record(error)
            }

        }
    }

    @Test
    func concurrentTransactionUpdates() async throws {
        try await runUsingTestClient { client in
            let suffix = randomTableSuffix()
            let table = "sessions_\(suffix)"
            let sessionID = "session_\(suffix)"

            enum TestError: Error {
                case missingRow
            }

            try await client.withConnection { connection in

                _ = try await connection.query(
                    #"""
                    DROP TABLE IF EXISTS "\#(table)";
                    """#
                )
                _ = try await connection.query(
                    #"""
                    CREATE TABLE "\#(table)" (
                        "id" TEXT NOT NULL PRIMARY KEY,
                        "access_token" TEXT NOT NULL,
                        "access_expires_at" INTEGER NOT NULL,
                        "refresh_token" TEXT NOT NULL,
                        "refresh_count" INTEGER NOT NULL DEFAULT 0
                    );
                    """#
                )

                _ = try await connection.query(
                    #"""
                    INSERT INTO "\#(table)"
                        ("id", "access_token", "access_expires_at", "refresh_token", "refresh_count")
                    VALUES
                        (
                            '\#(sessionID)',
                            'stale',
                            (strftime('%s','now') - 300),
                            'refresh',
                            0
                        );
                    """#
                )
            }

            func getValidAccessToken(
                sessionID: String
            ) async throws -> String {
                try await client.withTransaction { connection in

                    let updatedRows = try await connection.query(
                        #"""
                        UPDATE "\#(table)"
                        SET
                            "refresh_count" = "refresh_count" + 1,
                            "access_token" = 'token_' || ("refresh_count" + 1),
                            "access_expires_at" = (strftime('%s','now') + 600)
                        WHERE
                            "id" = '\#(sessionID)'
                            AND "access_expires_at"
                                <= (strftime('%s','now') + 60)
                        RETURNING "access_token";
                        """#
                    )

                    if let updatedRow = updatedRows.first {
                        return updatedRow.column("access_token")?.string ?? ""
                    }

                    let rows = try await connection.query(
                        #"""
                        SELECT
                            "access_token",
                            "refresh_count",
                            "access_expires_at" > (strftime('%s','now') + 60) AS "is_valid"
                        FROM "\#(table)"
                        WHERE "id" = '\#(sessionID)';
                        """#
                    )

                    guard let row = rows.first else {
                        throw TestError.missingRow
                    }

                    let isValid = row.column("is_valid")?.bool ?? false

                    #expect(isValid == true)

                    return row.column("access_token")?.string ?? ""
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

            let result = try await client.withConnection { connection in
                try await connection.query(
                    #"""
                    SELECT
                        "access_token",
                        "refresh_count",
                        "access_expires_at" > strftime('%s','now') AS "is_valid"
                    FROM "\#(table)"
                    WHERE "id" = '\#(sessionID)';
                    """#
                )
            }

            #expect(result.count == 1)
            #expect(result[0].column("refresh_count")?.integer == 1)
            #expect(result[0].column("access_token")?.string == "token_1")
            #expect(result[0].column("is_valid")?.bool == true)
        }
    }

    // MARK: - lock

    private actor LockBarrier {
        private var ready = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func waitUntilLocked() async {
            if ready { return }
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        func markLocked() {
            guard !ready else { return }
            ready = true
            let pending = waiters
            waiters.removeAll(keepingCapacity: false)
            for continuation in pending {
                continuation.resume()
            }
        }
    }

    @Test
    func warmupWaitsForTransientExclusiveLock() async throws {
        let dbPath =
            "/tmp/feather-lock-\(UInt64.random(in: 0...UInt64.max)).sqlite"

        var logger = Logger(label: "test.sqlite.lock.warmup")
        logger.logLevel = .info

        let config = SQLiteClient.Configuration(
            storage: .file(path: dbPath),
            logger: logger,
            minimumConnections: 1,
            maximumConnections: 1,
            journalMode: .delete,
            busyTimeoutMilliseconds: 5_000
        )

        let clientA = SQLiteClient(configuration: config)
        let clientB = SQLiteClient(configuration: config)

        try await clientA.run()
        defer {
            Task {
                await clientB.shutdown()
                await clientA.shutdown()
            }
        }

        let barrier = LockBarrier()

        let holder = Task {
            try await clientA.withConnection { connection in
                _ = try await connection.query("BEGIN EXCLUSIVE;")
                await barrier.markLocked()
                try await Task.sleep(for: .milliseconds(1200))
                _ = try await connection.query("COMMIT;")
            }
        }

        await barrier.waitUntilLocked()

        let clock = ContinuousClock()
        let start = clock.now

        try await clientB.run()
        try await clientB.withConnection { connection in
            _ = try await connection.query("SELECT 1;")
        }

        let elapsed = start.duration(to: clock.now)
        #expect(elapsed >= .milliseconds(900))

        _ = try await holder.value
    }

}
