import Foundation
import os.log

// MARK: - Facade

/// Writes textual representation of input parameters into standard debugger / device output.
/// - Parameters:
///   - items: Variadic parameter (zero or more values of `Any` type).
///   - fileID: Calling file ID (defaults to `#fileID`).
///   - line: Calling line number (defaults to `#line`).
///   - function: Calling function (defaults to `#function`).
public func log(
    _ items: Any...,
    fileID: String = #fileID,
    line: Int = #line,
    function: String = #function
) {
    guard Log.isEnabled else {
        return
    }
    Log.write(fileID: fileID, line: line, function: function, items: items)
}

// MARK: - LogEngine

/// Protocol for enabling different kinds of log engine.
public protocol LogEngine {
    func log(_ line: Log.Line)
}

private struct LogEnginePrint: LogEngine {
    func log(_ line: Log.Line) {
        print(line.description)
    }
}

private struct LogEngineNSLog: LogEngine {
    func log(_ line: Log.Line) {
        let template = Log.Line.defaultTemplate
            .replacingOccurrences(of: "{timestamp} ", with: "")
        let text = line.parse(template: template)
        NSLog(text)
    }
}

private struct LogEngineOSLog: LogEngine {
    let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "undefined",
        category: "main"
    )

    func log(_ line: Log.Line) {
        let template = Log.Line.defaultTemplate
            .replacingOccurrences(of: "{timestamp} -- [{thread}]", with: "--")
        let text = line.parse(template: template)
        logger.log("\(text)")
    }
}

// MARK: - Log

/// Simple logging mechanism.
public final class Log {

    /// Flag which determines if logging is enabled (defaults to `true`).
    public static var isEnabled = true

    /// Different kinds of `LogEngine`.
    public enum Engine {

        /// Writes log to debugger console only.
        case print
        /// Writes log to both debugger and device console.
        case nsLog
        /// Writes log to both debugger and device console.
        case osLog
        /// Option for providing a custom log engine.
        case custom(LogEngine)

        func make() -> LogEngine {
            switch self {
            case .print:
                return LogEnginePrint()
            case .nsLog:
                return LogEngineNSLog()
            case .osLog:
                return LogEngineOSLog()
            case .custom(let engine):
                return engine
            }
        }
    }

    /// Log engine kind to use for logging (defaults to `.print`).
    public static var engine: Engine = .print {
        didSet {
            _engine = engine.make()
        }
    }

    // MARK: Internal API

    static func write(
        thread: Thread = .current,
        fileID: String,
        line: Int,
        function: String,
        items: Any...
    ) {
        DispatchQueue.global(qos: .utility).async {
            let line = Line(
                thread: getThreadName(thread),
                file: extractFilename(fileID),
                number: line,
                function: function,
                text: makeString(items)
            )
            _engine.log(line)
        }
    }

    // MARK: Helpers

    private static var _engine: LogEngine = engine.make()

    private static func getThreadName(_ thread: Thread) -> String {
        if thread.isMainThread {
            return "main"
        } else if let name = thread.name, !name.isEmpty {
            return name
        } else {
            return String(format: "%p", thread)
        }
    }

    private static func extractFilename(_ path: String) -> String {
        let filename = URL(fileURLWithPath: path)
            .deletingPathExtension().lastPathComponent
        guard !filename.isEmpty else {
            return "Unknown"
        }
        return filename
    }

    private static func makeString(_ items: Any...) -> String {
        let array = items.first as? [Any] ?? items as [Any]
        switch array.count {
        case 0:
            return String()
        case 1:
            return "\(array.first.unsafelyUnwrapped)"
        default:
            var text = "\n\n"
            for (index, element) in array.enumerated() {
                let type = Mirror(reflecting: element).subjectType
                let description = String(reflecting: element)
                text += "#\(index): \(type) | \(description)\n"
            }
            return text
        }
    }

}

// MARK: - Log.Line

extension Log {

    /// Custom data structure used for log lines.
    public struct Line: CustomStringConvertible {

        // MARK: Settings

        /// Log line template.
        /// Defaults to: "{timestamp} -- [{thread}] {file} ({line}) : {function} > {text}"
        public static var template = defaultTemplate

        fileprivate static let defaultTemplate = "{timestamp} -- [{thread}] {file} ({line}) : {function} > {text}"

        /// Date format to be used in log lines.
        /// Defaults to: "yyyy-MM-dd HH:mm:ss.SSS"
        public static var dateFormat = "yyyy-MM-dd HH:mm:ss.SSS" {
            didSet {
                dateFormatter.dateFormat = dateFormat
            }
        }

        private static let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = dateFormat
            return df
        }()

        // MARK: Properties

        /// Timestamp
        public let timestamp = Date()

        /// Thread
        public let thread: String

        /// Filename (without extension)
        public let file: String

        /// Line number in code
        public let number: Int

        /// Function
        public let function: String

        /// Custom text
        public let text: String

        // MARK: CustomStringConvertible

        /// Concatenated text representation of a complete log line
        public var description: String {
            parse(template: Self.template)
        }

        /// Creates text representation using a given template.
        /// - Parameter template: Log line template
        /// - Returns: String representation of a log line.
        public func parse(template: String) -> String {
            template
                .replacingOccurrences(of: "{timestamp}", with: Self.dateFormatter.string(from: timestamp))
                .replacingOccurrences(of: "{thread}", with: thread)
                .replacingOccurrences(of: "{file}", with: file)
                .replacingOccurrences(of: "{line}", with: "\(number)")
                .replacingOccurrences(of: "{function}", with: function)
                .replacingOccurrences(of: "{text}", with: text)
        }

    }

}
