import Foundation

/// Simple wrapper around `FileManager`.
///
/// Usage example:
///
///     // data
///
///     let disk = Disk()
///     let url = ...
///     let data = try await disk.read(from: url)
///     try await disk.write(data, to: url)
///
///     // codable
///
///     struct Example: Codable {
///         let id: Int
///         let title: String
///     }
///
///     struct ExampleStorage {
///         let disk = Disk()
///
///         var fileURL: URL {
///             disk.documents.appendingPathComponent("example.json")
///         }
///
///         // async
///
///         func load() async throws -> Example {
///             try await disk.decode(from: fileURL)
///         }
///
///         func save(_ example: Example) async throws {
///             try await disk.encode(example, to: fileURL)
///         }
///
///         // combine
///
///         func load() -> AnyPublisher<Example, Error> {
///             disk.decode(from: fileURL)
///         }
///
///         func save(_ example: Example) -> AnyPublisher<Void, Error> {
///             disk.encode(example, to: fileURL)
///         }
///     }
///
public struct Disk {

    public let fm: FileManager

    public init(fm: FileManager = .default) {
        self.fm = fm
    }

    public var documents: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public var appSupport: URL {
        fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    public var caches: URL {
        fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

}

// MARK: - Async

public extension Disk {
    func read(from url: URL) async throws -> Data {
        try await Task.detached {
            try Data(contentsOf: url)
        }.value
    }

    func write(_ data: Data, to url: URL) async throws {
        try await Task.detached {
            try createPathIfNeeded(for: url)
            try data.write(to: url)
        }.value
    }

    func delete(at url: URL) async throws {
        try await Task.detached {
            try fm.removeItem(at: url)
        }.value
    }
}

public extension Disk {
    func decode<T: Decodable>(
        from url: URL,
        using decoder: JSONDecoder = .init()
    ) async throws -> T {
        let data = try await read(from: url)
        return try decoder.decode(T.self, from: data)
    }

    func encode<T: Encodable>(
        _ object: T,
        to url: URL,
        using encoder: JSONEncoder = .init()
    ) async throws {
        let data = try encoder.encode(object)
        try await write(data, to: url)
    }
}

public extension Disk {
    func contentsOfDirectory(
        at url: URL,
        including propertiesForKeys: [URLResourceKey]? = nil,
        options: FileManager.DirectoryEnumerationOptions = []
    ) async throws -> [URL] {
        try await Task.detached {
            try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: propertiesForKeys,
                options: options
            )
        }.value
    }

    func enumerate(
        at url: URL,
        including propertiesForKeys: [URLResourceKey]? = nil,
        options: FileManager.DirectoryEnumerationOptions = []
    ) -> AsyncStream<URL> {
        AsyncStream { continuation in
            Task.detached {
                let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: propertiesForKeys,
                    options: options
                )

                while let url = enumerator?.nextObject() as? URL {
                    if url.hasDirectoryPath {
                        for await item in enumerate(
                            at: url, including: propertiesForKeys, options: options
                        ) {
                            continuation.yield(item)
                        }
                    } else {
                        continuation.yield(url)
                    }
                }

                continuation.finish()
            }
        }
    }
}

// MARK: - Combine

#if canImport(Combine)

import Combine

public extension Disk {
    func read(from url: URL) -> Future<Data, Error> {
        Future { promise in
            do {
                let data = try Data(contentsOf: url)
                promise(.success(data))
            } catch {
                promise(.failure(error))
            }
        }
    }

    func write(_ data: Data, to url: URL) -> Future<Void, Error> {
        Future { promise in
            do {
                try createPathIfNeeded(for: url)
                try data.write(to: url)
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
    }

    func delete(at url: URL) -> Future<Void, Error> {
        Future { promise in
            do {
                try fm.removeItem(at: url)
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
    }
}

public extension Disk {
    func decode<T: Decodable>(
        from url: URL,
        using decoder: JSONDecoder = .init()
    ) -> AnyPublisher<T, Error> {
        read(from: url)
            .decode(type: T.self, decoder: decoder)
            .eraseToAnyPublisher()
    }

    func encode<T: Encodable>(
        _ object: T,
        to url: URL,
        using encoder: JSONEncoder = .init()
    ) -> AnyPublisher<Void, Error> {
        Just(object)
            .encode(encoder: encoder)
            .flatMap {
                write($0, to: url)
            }
            .eraseToAnyPublisher()
    }
}

#endif

// MARK: - Helpers

private extension Disk {
    func createPathIfNeeded(for url: URL) throws {
        let directoryURL = url.deletingLastPathComponent()
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
}
