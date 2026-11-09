import Foundation
import SQLite3

public enum SQLValue: Equatable, Sendable {
    case int(Int64)
    case double(Double)
    case text(String)
    case null

    public init(_ value: Int) { self = .int(Int64(value)) }
    public init(_ value: Bool) { self = .int(value ? 1 : 0) }
    public init(_ value: Double?) { self = value.map { .double($0) } ?? .null }
    public init(_ value: String?) { self = value.map { .text($0) } ?? .null }
    public init(_ value: Date?) { self = value.map { .double($0.timeIntervalSince1970) } ?? .null }
}

public struct DatabaseError: Error, CustomStringConvertible {
    public let description: String
}

/// One result row, read by column name.
public struct Row: Sendable {
    let values: [String: SQLValue]

    public func int(_ column: String) -> Int {
        switch values[column] {
        case .int(let v): Int(v)
        case .double(let v): Int(v)
        default: 0
        }
    }

    public func double(_ column: String) -> Double? {
        switch values[column] {
        case .int(let v): Double(v)
        case .double(let v): v
        default: nil
        }
    }

    public func text(_ column: String) -> String? {
        if case .text(let v) = values[column] { return v }
        return nil
    }

    public func bool(_ column: String) -> Bool { int(column) != 0 }
    public func date(_ column: String) -> Date? { double(column).map(Date.init(timeIntervalSince1970:)) }
}

/// A small typed wrapper over the system SQLite library. No ORM.
/// Not thread-safe by design: the app uses it from the main actor only.
public final class Database {
    private var handle: OpaquePointer?
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(path: String) throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
            throw DatabaseError(description: "Can't open database at \(path)")
        }
        try execute("PRAGMA foreign_keys = ON")
    }

    public static func inMemory() throws -> Database { try Database(path: ":memory:") }

    deinit { sqlite3_close(handle) }

    /// Runs one or more statements with no parameters.
    public func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(error)
            throw DatabaseError(description: message)
        }
    }

    public func run(_ sql: String, _ params: [SQLValue] = []) throws {
        let statement = try prepare(sql, params)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw lastError() }
    }

    public func query(_ sql: String, _ params: [SQLValue] = []) throws -> [Row] {
        let statement = try prepare(sql, params)
        defer { sqlite3_finalize(statement) }
        var rows: [Row] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { break }
            guard result == SQLITE_ROW else { throw lastError() }
            var values: [String: SQLValue] = [:]
            for i in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, i))
                switch sqlite3_column_type(statement, i) {
                case SQLITE_INTEGER: values[name] = .int(sqlite3_column_int64(statement, i))
                case SQLITE_FLOAT: values[name] = .double(sqlite3_column_double(statement, i))
                case SQLITE_TEXT: values[name] = .text(String(cString: sqlite3_column_text(statement, i)))
                default: values[name] = .null
                }
            }
            rows.append(Row(values: values))
        }
        return rows
    }

    /// All-or-nothing: rolls back if `body` throws.
    public func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN")
        do {
            let result = try body()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    public var userVersion: Int {
        get { (try? query("PRAGMA user_version").first?.int("user_version")) ?? 0 }
    }

    func setUserVersion(_ version: Int) throws {
        try execute("PRAGMA user_version = \(version)")
    }

    private func prepare(_ sql: String, _ params: [SQLValue]) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { throw lastError() }
        for (offset, param) in params.enumerated() {
            let i = Int32(offset + 1)
            switch param {
            case .int(let v): sqlite3_bind_int64(statement, i, v)
            case .double(let v): sqlite3_bind_double(statement, i, v)
            case .text(let v): sqlite3_bind_text(statement, i, v, -1, Self.transient)
            case .null: sqlite3_bind_null(statement, i)
            }
        }
        return statement
    }

    private func lastError() -> DatabaseError {
        DatabaseError(description: String(cString: sqlite3_errmsg(handle)))
    }
}
