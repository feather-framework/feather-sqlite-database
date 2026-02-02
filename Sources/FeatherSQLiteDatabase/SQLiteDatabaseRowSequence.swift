//
//  SQLiteQueryResult.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 10..
//

import FeatherDatabase
import SQLiteNIO

/// A query result backed by SQLite rows.
///
/// Use this type to iterate or collect SQLite query results.
public struct SQLiteDatabaseRowSequence: DatabaseRowSequence {
    public typealias Row = SQLiteDatabaseRow
    
    let elements: [Row]

    /// An async iterator over SQLite rows.
    ///
    /// This iterator traverses the in-memory row list.
    public struct Iterator: AsyncIteratorProtocol {
        var index = 0
        let elements: [Row]

        /// Return the next row in the sequence.
        ///
        /// This returns `nil` after the last row.
        /// - Returns: The next `SQLiteRow`, or `nil` when finished.
        public mutating func next() async -> Row? {
            guard index < elements.count else {
                return nil
            }
            defer { index += 1 }
            return elements[index]
        }
    }

    /// Create an async iterator over the result rows.
    ///
    /// Use this to iterate the result as an `AsyncSequence`.
    /// - Returns: An iterator over the result rows.
    public func makeAsyncIterator() -> Iterator {
        Iterator(elements: elements)
    }

    /// Collect all rows into an array.
    ///
    /// This returns the rows held by the result.
    /// - Throws: An error if collection fails.
    /// - Returns: An array of `SQLiteRow` values.
    public func collect() async throws -> [Row] {
        elements
    }
}
