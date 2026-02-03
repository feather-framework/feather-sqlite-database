//
//  SQLiteTransactionError.swift
//  feather-sqlite-database
//
//  Created by Tibor Bödecs on 2026. 01. 10..
//

import FeatherDatabase
import SQLiteNIOExtras

/// Transaction error details for SQLite operations.
///
/// Use this to capture errors from transaction phases.
public struct SQLiteDatabaseTransactionError: DatabaseTransactionError {

    var underlyingError: SQLiteTransactionError

    /// The source file where the error was created.
    ///
    /// This is captured with `#fileID` by default.
    public var file: String { underlyingError.file }
    /// The source line where the error was created.
    ///
    /// This is captured with `#line` by default.
    public var line: Int { underlyingError.line }

    /// The error thrown while beginning the transaction.
    ///
    /// Set when the `BEGIN` step fails.
    public var beginError: Error? { underlyingError.beginError }
    /// The error thrown inside the transaction closure.
    ///
    /// Set when the closure fails before commit.
    public var closureError: Error? { underlyingError.closureError }
    /// The error thrown while committing the transaction.
    ///
    /// Set when the `COMMIT` step fails.
    public var commitError: Error? { underlyingError.commitError }
    /// The error thrown while rolling back the transaction.
    ///
    /// Set when the `ROLLBACK` step fails.
    public var rollbackError: Error? { underlyingError.rollbackError }

}
