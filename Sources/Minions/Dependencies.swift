import Foundation

/// Simple mechanism for managing dependencies.
///
/// Supports static and dynamic registration of dependencies,
/// while both can be resolved via `@Dependency` property wrapper.
///
public struct Dependencies {}

// MARK: - Static

/// Key for accessing dependencies in different contexts.
///
/// Conform custom types to this protocol for static dependency registration.
/// Only `liveValue` is required to implement (used when running the app), while
/// `previewValue` and `testValue` will fallback to it if not explicitly defined.
///
/// Usage example:
///
///     // custom dependency type
///     protocol CustomDependency {}
///
///     // different implementations
///     final class LiveCustomDependency: CustomDependency {}
///     final class PreviewCustomDependency: CustomDependency {}
///     final class TestCustomDependency: CustomDependency {}
///
///     // make dependency accessible in different contexts
///     struct CustomDependencyKey: DependencyKey {
///         static var liveValue: CustomDependency = LiveCustomDependency()
///         static var previewValue: CustomDependency = PreviewCustomDependency()
///         static var testValue: CustomDependency = TestCustomDependency()
///     }
///
///     // register custom dependency using its `DependencyKey`
///     extension Dependencies {
///         var custom: CustomDependency {
///             get { Self[CustomDependencyKey.self] }
///             set { Self[CustomDependencyKey.self] = newValue }
///         }
///     }
///
///     // resolve custom dependency using a property wrapper
///     final class CustomViewModel: ObservableObject {
///         @Dependency(\.custom) var custom
///     }
///
public protocol DependencyKey {
    associatedtype Value

    /// Dependency instance used when running the app.
    static var liveValue: Value { get set }

    /// Dependency instance used in Xcode Previews.
    static var previewValue: Value { get set }

    /// Dependency instance used in Xcode Simulator.
    static var simulatorValue: Value { get set }

    /// Dependency instance used when running tests.
    static var testValue: Value { get set }
}

extension DependencyKey {

    public static var previewValue: Value {
        get { Self.liveValue }
        set { Self.previewValue = newValue }
    }

    public static var simulatorValue: Value {
        get { Self.liveValue }
        set { Self.simulatorValue = newValue }
    }

    public static var testValue: Value {
        get { Self.liveValue }
        set { Self.testValue = newValue }
    }

    /// Dependency instance for the current context.
    internal static var contextValue: Value {
        get {
            switch Dependencies.context {
            case .live:
                return Self.liveValue
            case .preview:
                return Self.previewValue
            case .simulator:
                return Self.simulatorValue
            case .test:
                return Self.testValue
            }
        }
        set {
            switch Dependencies.context {
            case .live:
                Self.liveValue = newValue
            case .preview:
                Self.previewValue = newValue
            case .simulator:
                Self.simulatorValue = newValue
            case .test:
                Self.testValue = newValue
            }
        }
    }
}

extension Dependencies {

    /// Environment context
    public enum Context: String {
        case live, preview, test, simulator
    }

    /// Current context.
    public static var context: Context {
        if ProcessInfo.isXcodePreview {
            return .preview
        } else if ProcessInfo.isXcodeUnitTest || ProcessInfo.isXcodeUITest {
            return .test
        } else if ProcessInfo.isXcodeSimulator {
            return .simulator
        } else {
            return .live
        }
    }

    private static var shared = Dependencies()

    /// A static subscript for accessing dependency value in current context.
    public static subscript<K>(_ key: K.Type) -> K.Value where K: DependencyKey {
        get { key.contextValue }
        set { key.contextValue = newValue }
    }

    /// A static subscript for direct access to dependency reference.
    public static subscript<T>(_ keyPath: WritableKeyPath<Dependencies, T>) -> T {
        get { shared[keyPath: keyPath] }
        set { shared[keyPath: keyPath] = newValue }
    }

}

// MARK: - Property Wrapper

/// A property wrapper for accessing / resolving dependencies.
///
/// Statically registered dependencies can be accessed by using their keyPath:
///
///     @Dependency(\.apiClient) var apiClient
///
/// Dynamically registered dependencies can be resolved by using their type:
///
///     @Dependency(ApiClient.self) var apiClient
///
@propertyWrapper
public struct Dependency<T> {

    public var wrappedValue: T {
        get {
            switch kind {
            case .static(let keyPath):
                return Dependencies[keyPath]
            case .dynamic(let type):
                return Dependencies.resolve(type)
            }
        }
        set {
            switch kind {
            case .static(let keyPath):
                Dependencies[keyPath] = newValue
            case .dynamic:
                assertionFailure("⚠️ dynamic dependency does not support property wrapper setter")
            }
        }
    }

    public init(_ keyPath: WritableKeyPath<Dependencies, T>) {
        self.init(.static(keyPath))
    }

    public init(_ type: T.Type) {
        self.init(.dynamic(type))
    }

    internal init(_ kind: Kind) {
        self.kind = kind
    }

    internal let kind: Kind

    internal enum Kind {
        case `static`(WritableKeyPath<Dependencies, T>)
        case `dynamic`(T.Type)
    }

}

// MARK: - Dynamic

public extension Dependencies {

    // MARK: Facade

    /// Registers a custom dependency which is resolved by creating a new instance.
    ///
    /// - Parameters:
    ///   - type: type of the instance
    ///   - factory: closure called to create a new instance
    ///
    /// Example usage:
    ///
    ///     Dependencies.registerFactory(CustomDependency.self, LiveCustomDependency())
    ///
    static func registerFactory<T>(_ type: T.Type, _ factory: @autoclosure @escaping () -> T) {
        container.register(.factory(type), factory: factory())
    }

    /// Registers a custom dependency which is resolved by returning the same instance.
    ///
    /// - Parameters:
    ///   - type: type of the instance
    ///   - factory: closure called to create a new instance
    ///
    /// Example usage:
    ///
    ///     Dependencies.registerSingleton(CustomDependency.self, LiveCustomDependency())
    ///
    static func registerSingleton<T>(_ type: T.Type, _ factory: @autoclosure @escaping () -> T) {
        container.register(.singleton(type), factory: factory())
    }

    static func resolve<T>(_ type: T.Type) -> T {
        container.resolve(type)
    }

    // MARK: Implementation

    private static let container = Container()

    /// A simple `Container` used for registering and resolving dependencies dynamically.
    private final class Container {

        enum Dependency<T> {
            case factory(T.Type)
            case singleton(T.Type)
        }

        private var factories = [ObjectIdentifier: () -> Any]()
        private var singletons = [ObjectIdentifier: Any]()

        private var lock = NSRecursiveLock()

        internal func register<T>(_ dependency: Dependency<T>, factory: @autoclosure @escaping () -> T) {
            lock.lock()
            defer { lock.unlock() }

            let key = ObjectIdentifier(T.self)

            switch dependency {
            case .factory:
                factories[key] = factory
            case .singleton:
                singletons[key] = factory()
            }
        }

        internal func resolve<T>(_ type: T.Type) -> T {
            lock.lock()
            defer { lock.unlock() }

            let key = ObjectIdentifier(T.self)

            if let singleton = singletons[key] as? T {
                return singleton
            } else if let factory = factories[key], let newInstance = factory() as? T {
                return newInstance
            } else {
                fatalError("❌ could not find instance for type: \"\(String(describing: type))\"")
            }
        }
    }

}

// MARK: - Helpers

public extension ProcessInfo {

    /// A flag which determines if code is run in the context of Xcode's "Live Preview"
    static var isXcodePreview: Bool {
        processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// A flag which determines if code is run in the context of Xcode's "Simulator"
    static var isXcodeSimulator: Bool {
        processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
    }

    /// A flag which determines if code is run in the context of Xcode's "Unit Tests"
    static var isXcodeUnitTest: Bool {
        processInfo.environment.keys.contains("XCTestConfigurationFilePath")
    }

    /// A flag which determines if code is run in the context of Xcode's "UI Tests"
    static var isXcodeUITest: Bool {
        processInfo.arguments.contains("UITests")
    }

}
