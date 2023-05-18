import Foundation

/// Provides information about build configuration and custom config.
///
/// To enable, define "Config" dictionary within "Info.plist" file.
/// Add any custom items to this dictionary, for example:
/// key: "buildConfiguration" | type: String | value: $(CONFIGURATION)
///
/// - Attention: Make sure to keep this "Config" dictionary in sync
/// across all targets that will use it (for each target's "Info.plist").
///
/// Example of a posssible usage:
///
///     extension BuildConfig {
///         var isDev: Bool {
///             current.contains("Dev")
///         }
///
///         var isLive: Bool {
///             current.contains("Live")
///         }
///     }
///
public struct BuildConfig {

    public let info: InfoPlist

    /// Build config provider
    ///
    /// - Parameters:
    ///   - info: "Info.plist" (defaults to `.init(bundle: Bundle = .main)`)
    ///   - customConfigKey: key for a custom config in "Info.plist" (defaults to "Config")
    ///
    public init(
        info: InfoPlist = .init(),
        customConfigKey: String = "Config",
        buildConfigKey: String = "buildConfiguration"
    ) {
        self.info = info
        self.customConfigKey = customConfigKey
        self.buildConfigKey = buildConfigKey
    }

    /// Access to custom "Config" dictionary from "Info.plist"
    public var customConfig: [String: Any] {
        info[customConfigKey] as? [String: Any] ?? [:]
    }

    /// Current build configuration read from `customConfig`
    var current: String {
        customConfig["buildConfiguration"] as? String ?? "n/a"
    }

    private let customConfigKey: String
    private let buildConfigKey: String

}

extension BuildConfig: CustomStringConvertible {

    /// Multi-line string with basic environment information
    public var description: String {
        """
        product name: \(productName)
        bundle id: \(bundleID)
        bundle version: \(bundleVersion)
        bundle build: \(bundleBuild)
        """
    }

    /// Product name
    public var productName: String {
        info.string(forKey: kCFBundleNameKey as String)
    }

    /// Bundle identifier
    public var bundleID: String {
        info.string(forKey: kCFBundleIdentifierKey as String)
    }

    /// Bundle version
    public var bundleVersion: String {
        info.string(forKey: "CFBundleShortVersionString")
    }

    /// Bundle build
    public var bundleBuild: String {
        info.string(forKey: kCFBundleVersionKey as String)
    }

    /// Bundle version and build formatted as "Version (Build)"
    public var versionBuild: String {
        "\(bundleVersion) (\(bundleBuild))"
    }

    /// A flag which determines if code is run in the context of Test Flight build
    public var isTestFlight: Bool {
        info.bundle.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

}
