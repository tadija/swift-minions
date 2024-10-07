#if canImport(Foundation)

import Foundation

// MARK: - Bundle Helpers

public extension Bundle {
    func decode<T: Decodable>(_ type: T.Type, from file: String) -> T {
        guard let url = url(forResource: file, withExtension: nil) else {
            fatalError("Failed to locate \(file) in bundle.")
        }

        guard let data = try? Data(contentsOf: url) else {
            fatalError("Failed to load \(file) from bundle.")
        }

        let decoder = JSONDecoder()

        guard let loaded = try? decoder.decode(T.self, from: data) else {
            fatalError("Failed to decode \(file) from bundle.")
        }

        return loaded
    }
}

// MARK: - Codable Helpers

/// - See: https://www.swiftbysundell.com/posts/type-inference-powered-serialization-in-swift
public extension KeyedDecodingContainerProtocol {
    func decode<T: Decodable>(_ key: Key) throws -> T {
        try decode(T.self, forKey: key)
    }

    func decodeIfPresent<T: Decodable>(_ key: Key) throws -> T? {
        try decodeIfPresent(T.self, forKey: key)
    }

    func decodeDate(_ key: Key, using formatter: DateFormatter) throws -> Date? {
        let dateString = try decodeIfPresent(key) ?? ""
        return formatter.date(from: dateString)
    }

    func decodeDates(_ key: Key, using formatter: DateFormatter) throws -> [Date]? {
        let strings: [String] = try decodeIfPresent(key) ?? []
        return strings.compactMap({ formatter.date(from: $0) })
    }
}

public extension KeyedEncodingContainerProtocol {
    mutating func encode(
        _ date: Date?,
        using formatter: DateFormatter,
        forKey key: Key
    ) throws {
        var dateString: String?
        if let date = date {
            dateString = formatter.string(from: date)
        }
        try encode(dateString, forKey: key)
    }

    mutating func encode(
        _ dates: [Date]?,
        using formatter: DateFormatter,
        forKey key: Key
    ) throws {
        var dateStrings: [String]?
        if let dates = dates {
            dateStrings = dates.compactMap({ formatter.string(from: $0) })
        }
        try encode(dateStrings, forKey: key)
    }
}

// MARK: - Data Helpers

public extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0 ..< len {
            let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }

    var hexString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}

public extension Data {
    enum SerializationError: Swift.Error {
        case jsonSerializationFailed
    }

    init(jsonWith any: Any) throws {
        self = try JSONSerialization.data(
            withJSONObject: any, options: .prettyPrinted
        )
    }

    func jsonDictionary() throws -> [String: Any] {
        try serializeJSON()
    }

    func jsonArray() throws -> [Any] {
        try serializeJSON()
    }

    private func serializeJSON<T>() throws -> T {
        let jsonObject = try JSONSerialization.jsonObject(
            with: self, options: .allowFragments
        )
        guard let parsed = jsonObject as? T else {
            throw SerializationError.jsonSerializationFailed
        }
        return parsed
    }
}

// MARK: - Date Helpers

public extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date? {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)
    }

    var isBeforeToday: Bool {
        self < Calendar.current.startOfDay(for: Date())
    }

    func isBetween(_ date1: Date, and date2: Date) -> Bool {
        (min(date1, date2) ... max(date1, date2)).contains(self)
    }

    var zeroSeconds: Date? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        return calendar.date(from: components)
    }

    func withTime(hour: Int, minute: Int, second: Int = 0) -> Date? {
        Calendar.current
            .date(bySettingHour: hour, minute: minute, second: second, of: self)
    }
}

// MARK: - Dictionary Helpers

public extension Dictionary {
    func jsonEncode() throws -> Data {
        try JSONSerialization.data(
            withJSONObject: self,
            options: .prettyPrinted
        )
    }

    func jsonDecode<T: Codable>() throws -> T {
        let data = try JSONSerialization.data(withJSONObject: self)
        let result = try JSONDecoder().decode(T.self, from: data)
        return result
    }
}

// MARK: - Double Helpers

public extension Double {
    func roundTo(places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded(.toNearestOrAwayFromZero) / divisor
    }

    func toString(roundedTo places: Int) -> String {
        String(format: "%.\(places)f", roundTo(places: places))
    }
}

// MARK: - Locale Helpers

public extension Locale {
    /// - See: https://stackoverflow.com/a/12236693/2165585
    var isFormat12h: Bool {
        format.contains("a")
    }

    /// - See: https://stackoverflow.com/a/49438640/2165585
    var isFormat24h: Bool {
        !format.contains("a")
    }

    private var format: String {
        DateFormatter
            .dateFormat(fromTemplate: "j", options: 0, locale: self) ?? ""
    }
}

// MARK: - String Helpers

extension String: @retroactive LocalizedError {
    public var errorDescription: String? {
        self
    }
}

public extension String {
    var isBlank: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
    }

    var isNotBlank: Bool {
        !isBlank
    }

    var isValidEmail: Bool {
        validate(regex: "^.+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2}[A-Za-z]*$")
    }

    var isNumeric: Bool {
        validate(regex: "^[0-9]+$")
    }

    var isValidPhoneNumber: Bool {
        /// - Note: starts with 0, maximum 10 digits
        validate(regex: "^(?=0)[0-9]{10}$")
    }

    var isValidYear: Bool {
        /// - Note: has 4 digits
        validate(regex: #"^\d{4}$"#)
    }

    var isStrongPassword: Bool {
        /// - Note: lowercase, uppercase, digit, 8-50 chars
        validate(regex: "((?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,50})")
    }

    private func validate(regex: String) -> Bool {
        let test = NSPredicate(format: "SELF MATCHES %@", regex)
        return test.evaluate(with: self)
    }
}

#endif
