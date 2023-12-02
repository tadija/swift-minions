import Foundation

// MARK: - Default

/// Simple mechanism for interacting with REST APIs.
///
/// Here are a few usage examples:
///
///     // without base URL
///     let api = RestAPI()
///     let response = try await api.fetch("https://httpbin.org/anything")
///
///     // with base URL
///     let api = RestAPI("https://httpbin.org")
///     let response = try await api.fetch("anything")
///
///     // with `RestAPIRequest`
///     let api = RestAPI("https://httpbin.org")
///     let response = try await api.fetch(Anything())
///
///     struct Anything: RestAPIRequest {
///         var method: URLRequest.Method {
///             .get
///         }
///         var path: String {
///             "anything"
///         }
///     }
///
///     // decode `RestAPIResponse` into custom `Codable` type
///     struct Model: Codable {}
///     response.decode(as: Model.self)
///
///     // or serialize JSON data into dictionary
///     response.asDictionary()
///
public struct RestAPI: RestAPIClient {
    public var api: APIFactory
    public var session: URLSession

    /// Initializes a new `RestAPI` instance.
    /// - Parameters:
    ///   - baseURL: The base URL for constructing API requests (default: .root).
    ///   - session: The `URLSession` used for making requests (default: .shared).
    public init(
        _ baseURL: URL = .root,
        session: URLSession = .shared
    ) {
        api = APIFactory(baseURL: baseURL)
        self.session = session
    }

    public struct APIFactory: RestAPIFactory {
        public var baseURL: URL
    }
}

// MARK: - Types

/// Protocol defining methods for constructing, sending, and parsing API requests.
public protocol RestAPIClient {
    associatedtype T: RestAPIFactory

    var api: T { get }
    var session: URLSession { get }

    func fetch(_ urlRequest: URLRequest) async throws -> RestAPIResponse
}

/// Protocol defining methods for creating `URLRequest` based on `RestAPIRequest`.
public protocol RestAPIFactory {
    var baseURL: URL { get }

    func makeURLRequest(_ apiRequest: RestAPIRequest) -> URLRequest
}

/// Protocol defining properties for creating an API request.
public protocol RestAPIRequest {
    var method: URLRequest.Method { get }
    var path: String { get }

    var headers: [String: String]? { get }
    var urlParameters: [String: Any]? { get }

    var bodyParameters: [String: Any]? { get }
    var body: Data? { get }

    var cachePolicy: URLRequest.CachePolicy? { get }
}

/// Structure representing the result of an API request,
/// containing the original request, HTTP response, and data.
public struct RestAPIResponse {
    public let request: URLRequest
    public let response: HTTPURLResponse
    public let data: Data

    public init(request: URLRequest, response: HTTPURLResponse, data: Data) {
        self.request = request
        self.response = response
        self.data = data
    }
}

public enum RestAPIError: Error {
    case badResponse
    case badStatus(code: Int)
}

// MARK: - Extensions

public extension RestAPIClient {

    /// Instance of `URLSession` used for fetching requests.
    var session: URLSession {
        .shared
    }

    /// Fetches a `URLRequest` and returns a `RestAPIResponse`.
    /// - Parameter urlRequest: `URLRequest` to be fetched.
    func fetch(_ urlRequest: URLRequest) async throws -> RestAPIResponse {
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RestAPIError.badResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return RestAPIResponse(request: urlRequest, response: httpResponse, data: data)
        default:
            throw RestAPIError.badStatus(code: httpResponse.statusCode)
        }
    }

    /// Constructs and sends a request with the specified parameters and returns a `RestAPIResponse`.
    func fetch(
        _ url: URL,
        method: URLRequest.Method = .get,
        headers: [String: String]? = nil,
        urlParameters: [String: Any]? = nil,
        body: Data? = nil
    ) async throws -> RestAPIResponse {
        let request = api.makeURLRequest(
            method: method,
            url: url,
            headers: headers,
            urlParameters: urlParameters,
            body: body
        )
        return try await fetch(request)
    }

    /// Fetches a `RestAPIRequest` and returns a `RestAPIResponse`.
    func fetch(_ apiRequest: RestAPIRequest) async throws -> RestAPIResponse {
        let request = api.makeURLRequest(apiRequest)
        return try await fetch(request)
    }

}

public extension RestAPIFactory {

    /// Constructs a `URLRequest` with HTTP method, URL, headers, URL parameters, and body data.
    func makeURLRequest(
        method: URLRequest.Method,
        url: URL,
        headers: [String: String]? = nil,
        urlParameters: [String: Any]? = nil,
        body: Data? = nil
    ) -> URLRequest {
        URLRequest(
            method: method,
            url: baseURL == .root ? url : baseURL.appendingPathComponent(url.absoluteString),
            headers: headers,
            urlParameters: urlParameters,
            body: body
        )
    }

    /// Constructs a `URLRequest` based on a `RestAPIRequest`.
    func makeURLRequest(_ apiRequest: RestAPIRequest) -> URLRequest {
        var request = URLRequest(
            method: apiRequest.method,
            url: baseURL.appendingPathComponent(apiRequest.path),
            headers: apiRequest.headers,
            urlParameters: apiRequest.urlParameters,
            body: apiRequest.body
        )
        if let cachePolicy = apiRequest.cachePolicy {
            request.cachePolicy = cachePolicy
        }
        return request
    }

}

/// Default implementation for `RestAPIRequest`
public extension RestAPIRequest {

    var headers: [String: String]? {
        nil
    }

    var urlParameters: [String: Any]? {
        nil
    }

    var bodyParameters: [String: Any]? {
        nil
    }

    var body: Data? {
        guard
            method != .get,
            let bodyParameters,
            let json = try? bodyParameters.jsonEncode()
        else {
            return nil
        }
        return json
    }

    var cachePolicy: URLRequest.CachePolicy? {
        nil
    }

}

public extension RestAPIResponse {

    /// Status code of a HTTP Response.
    var statusCode: Int {
        response.statusCode
    }

    /// All headers of a HTTP Response.
    var headers: [AnyHashable: Any] {
        response.allHeaderFields
    }

    /// Short description of original request and response.
    var shortDescription: String {
        "Request: \(request.shortDescription) | Response: \(response.shortDescription)"
    }

    /// Full description of original request and response.
    var fullDescription: String {
        "\(request.fullDescription)\n\(response.fullDescription)"
    }

    func asString(using encoding: String.Encoding = .utf8) -> String {
        String(data: data, encoding: encoding) ?? ""
    }

    /// Response data as JSON dictionary
    func asDictionary() throws -> [String: Any] {
        try data.jsonDictionary()
    }

    /// Response data as JSON array
    func asArray() throws -> [Any] {
        try data.jsonArray()
    }

    /// Decodes response data into generic `Codable` type.
    func decode<T: Codable>(
        as type: T.Type,
        using decoder: JSONDecoder = .init()
    ) async throws -> T {
        try decoder.decode(type, from: data)
    }

}

// MARK: - Helpers

extension URL: ExpressibleByStringLiteral, Identifiable {

    /// Helper for constructing `URL` using `String` literals.
    public init(stringLiteral value: String) {
        guard let url = URL(string: value) else {
            preconditionFailure("Invalid URL string: \(value)")
        }
        self = url
    }

    /// Identifiable
    public var id: URL {
        self
    }

    /// Root `URL` constant.
    public static var root: Self {
        "/"
    }

}

public extension URL {

    /// Retrieves URL parameters as a dictionary.
    var parameters: [String: String]? {
        guard
            let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
        else {
            return nil
        }
        return queryItems.reduce(into: [String: String]()) {
            $0[$1.name] = $1.value
        }
    }

    /// Adds URL parameters to the URL and returns the new one.
    func addingParameters(_ parameters: [String: Any]) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.queryItems = parameters.map {
            URLQueryItem(name: $0.0, value: "\($0.1)")
        }
        return components?.url
    }

}

public extension URLRequest {

    /// An enumeration of HTTP methods.
    enum Method: String {
        case connect, delete, get, head, options, patch, post, put, trace
    }

    /// Initializes a URLRequest with method, URL, headers, URL parameters, and body data.
    init(
        method: Method,
        url: URL,
        headers: [String: String]? = nil,
        urlParameters: [String: Any]? = nil,
        body: Data? = nil
    ) {
        if
            let urlParameters = urlParameters,
            let urlWithParameters = url.addingParameters(urlParameters)
        {
            self.init(url: urlWithParameters)
        } else {
            self.init(url: url)
        }
        httpMethod = method.rawValue.uppercased()
        allHTTPHeaderFields = headers
        if let body = body {
            httpBody = body
        }
    }

    /// Generates a short description of the `URLRequest`.
    var shortDescription: String {
        let method = (httpMethod ?? "N/A").uppercased()
        let url = url?.absoluteString ?? "n/a"
        return "\(method) \(url)"
    }

    /// Generates a full description of the `URLRequest`, including headers, parameters, and body.
    var fullDescription: String {
        let headers = "\(allHTTPHeaderFields ?? [:])"
        let parameters = "\(url?.parameters ?? [:])"
        let body = (try? httpBody?.jsonDictionary()) ?? [:]
        return """
        - Request: \(shortDescription)
        - Headers: \(headers)
        - Parameters: \(parameters)
        - Body: \(body)
        """
    }

}

public extension HTTPURLResponse {

    /// Retrieves the header value for a specific key.
    func headerValue(forKey key: String) -> Any? {
        let foundKey: String = allHeaderFields.keys
            .first {
                "\($0)".caseInsensitiveCompare(key) == .orderedSame
            } as? String ?? key
        return allHeaderFields[foundKey]
    }

    /// Generates a short description of the `HTTPURLResponse`.
    var shortDescription: String {
        let code = statusCode
        let status = HTTPURLResponse.localizedString(forStatusCode: code).capitalized
        return "\(code) \(status)"
    }

    /// Generates a full description of the `HTTPURLResponse`, including headers.
    var fullDescription: String {
        let headers = "\(allHeaderFields as? [String: Any] ?? [String: String]())"
        return """
        - Response: \(shortDescription)
        - Headers: \(headers)
        """
    }

}
