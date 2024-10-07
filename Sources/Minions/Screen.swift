#if os(iOS) || os(watchOS)

import SwiftUI

#if os(watchOS)
import WatchKit
#endif

#if os(macOS)
import AppKit
#endif

/// Provides screen size in inches + other screen related helpers.
public struct Screen: CustomStringConvertible {

    public let nativeBounds: CGRect
    public let inchSize: Double

    public var mmSize: Double {
        (inchSize * 25.4).rounded(.toNearestOrAwayFromZero)
    }

    public var description: String {
        "screenBounds: \(nativeBounds.size) | inchSize: \(inchSize) | mmSize: \(mmSize)"
    }

    public init() {
        #if os(iOS)
        nativeBounds = UIScreen.main.nativeBounds
        #elseif os(watchOS)
        nativeBounds = WKInterfaceDevice.current().screenBounds
        #elseif os(macOS)
        nativeBounds = NSScreen.main?.nativeBounds
        #else
        nativeBounds = .zero
        #endif

        inchSize = Device().determineScreenSize(for: nativeBounds)

        logWrite(description)
    }

    public var bounds: CGRect {
        #if os(iOS)
        UIScreen.main.bounds
        #elseif os(watchOS)
        WKInterfaceDevice.current().screenBounds
        #elseif os(macOS)
        NSScreen.main?.bounds
        #else
        CGRect.zero
        #endif
    }

    public var isZoomed: Bool {
        #if os(iOS)
        let screen = UIScreen.main
        return screen.scale < screen.nativeScale
        #elseif os(macOS)
        let screen = NSScreen.main
        return screen?.scale < screen?.nativeScale
        #else
        false
        #endif
    }

#if os(iOS)
    public func makeSnapshot() -> UIImage? {
        UIWindow.keyWindow?
            .rootViewController?.view
            .renderLayer()
    }
#endif

}

// MARK: - Helpers

private extension Device {

    func determineScreenSize(for bounds: CGRect) -> Double {

        switch max(bounds.width, bounds.height) {

            /// - Note: Watches

        case 170:
            /// 1st, Series 1, 2, 3 Small (38mm)
            return 1.496
        case 195:
            /// 1st, Series 1, 2, 3 Large (42mm)
            return 1.653

        case 197:
            /// Series 4, 5, 6, SE1, SE2 Small (40mm)
            return 1.574
        case 224:
            /// Series 4, 5, 6, SE1, SE2 Large (44mm)
            return 1.732

        case 215:
            /// Series 7, 8, 9 Small (41mm)
            return 1.614
        case 242:
            /// Series 7, 8, 9 Large (45mm)
            return 1.771

        case 251:
            /// Ultra 1, 2
            return 1.929

            /// - Note: iPhones
            /// - See: https://ios-resolution.com

        case 480, 960:
            /// 1st, 3G, 3GS, 4, 4s
            /// iPod Touch (1, 2, 3, 4)
            return 3.5
        case 1136:
            /// 5, 5s, 5c, SE
            /// iPod Touch (5, 6)
            return 4
        case 1334:
            /// 6, 6s, 7, 8, SE2
            return 4.7
        case 2340:
            /// 12 Mini, 13 Mini
            return 5.4
        case 2208:
            /// 6+, 6s+, 7+, 8+
            return 5.5
        case 2436:
            /// X, Xs, 11 Pro
            return 5.8
        case 1792:
            /// XR, 11
            return 6.1
        case 2532:
            /// 12, 12 Pro, 13, 13 Pro, 14
            return 6.06
        case 2556:
            /// 14 Pro, 15, 15 Pro, 16
            return 6.1
        case 2622:
            /// 16 Pro
            return 6.3
        case 2688:
            /// Xs Max, 11 Pro Max
            return 6.5
        case 2778:
            /// 12 Pro Max, 13 Pro Max, 14 Plus
            return 6.7
        case 2796:
            /// 14 Pro Max, 15+, 15 Pro Max, 16+
            return 6.7
        case 2868:
            /// 16 Pro Max
            return 6.9

            /// - Note: iPads

        case 1024:
            /// 1st, 2, Mini
            return iPadMinis.contains(model) ? 7.9 : 9.7
        case 2048:
            /// 3, 4, Air, Pro, Mini (2, 3, 4, 5)
            return iPadMinis.contains(model) ? 7.9 : 9.7
        case 2266:
            /// Mini 6
            return 8.3
        case 2160:
            /// 7, 8, 9
            return 10.2
        case 2224:
            /// Air 3, Pro 2
            return 10.5
        case 2360:
            /// Air 4, 10
            return 10.86
        case 2388:
            /// Pro 11 (3, 4, 5, 6)
            return 11
        case 2732:
            /// Pro 12.9 (1, 2, 3, 4, 5, 6)
            return 12.9

            /// - Note: Unknown

        default:
            logWrite("⚠️ unsupported screen size")
            return defaultInchSize
        }

    }

    private var defaultInchSize: Double {
        return switch kind {
        case .iPhone: 7
        case .iPad: 10
        case .iPod: 4
        case .watch: 2
        case .mac: 14
        case .tv: 50
        case .spatial: 21
        case .unknown: 1
        }
    }

    /// - See: https://github.com/Ekhoo/Device
    private var iPadMinis: [String] {[
        "iPad2,5", "iPad2,6", "iPad2,7",
        "iPad4,4", "iPad4,5", "iPad4,6",
        "iPad4,7", "iPad4,8", "iPad4,9",
        "iPad5,1", "iPad5,2"
    ]}

}

#endif
