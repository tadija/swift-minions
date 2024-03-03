import SwiftUI

#if canImport(WatchKit)
import WatchKit
#endif

/// Triggers haptic feedback on iOS / watchOS.
///
/// Usage example:
///
///     let haptics = Haptics()
///     haptics.signal(.success)
///
public struct Haptics {

    public enum Signal: String, CaseIterable {
        case success, warning, error
        case light, medium, heavy
        case selection
    }

    public init() {}

    public func signal(_ signal: Signal) {
        #if os(iOS)
        self.signalMobile(signal.mobile)
        #elseif os(watchOS)
        self.signalWatch(signal.watch)
        #endif
    }

    #if os(iOS)
    public typealias SignalMobile = Signal

    public func signalMobile(_ signal: SignalMobile) {
        switch signal {
        case .success:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        case .warning:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.warning)
        case .error:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.error)
        case .light:
            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.impactOccurred()
        case .medium:
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
        case .heavy:
            let feedback = UIImpactFeedbackGenerator(style: .heavy)
            feedback.impactOccurred()
        case .selection:
            let feedback = UISelectionFeedbackGenerator()
            feedback.selectionChanged()
        }
    }
    #endif

    #if os(watchOS)
    public typealias SignalWatch = WKHapticType

    public func signalWatch(_ signal: SignalWatch) {
        WKInterfaceDevice.current().play(signal)
    }
    #endif

}

#if os(watchOS)
extension WKHapticType: CaseIterable {
    public static var allCases: [WKHapticType] {[
        .notification,
        .directionUp,
        .directionDown,
        .success,
        .failure,
        .retry,
        .start,
        .stop,
        .click,
        .navigationGenericManeuver,
        .navigationLeftTurn,
        .navigationRightTurn,
        .underwaterDepthPrompt,
        .underwaterDepthCriticalPrompt
    ]}

    var name: String {
        switch self {
        case .notification: "notification"
        case .directionUp: "directionUp"
        case .directionDown: "directionDown"
        case .success: "success"
        case .failure: "failure"
        case .retry: "retry"
        case .start: "start"
        case .stop: "stop"
        case .click: "click"
        case .navigationLeftTurn: "navigationLeftTurn"
        case .navigationRightTurn: "navigationRightTurn"
        case .navigationGenericManeuver: "navigationGenericManeuver"
        case .underwaterDepthPrompt: "underwaterDepthPrompt"
        case .underwaterDepthCriticalPrompt: "underwaterDepthCriticalPrompt"
        @unknown default: "unknown"
        }
    }
}
#endif

extension Haptics.Signal {
    #if os(iOS)
    var mobile: Haptics.SignalMobile {
        switch self {
        case .success: .success
        case .warning: .warning
        case .error: .error
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        case .selection: .selection
        }
    }
    #endif

    #if os(watchOS)
    var watch: Haptics.SignalWatch {
        switch self {
        case .success: .success
        case .warning: .retry
        case .error: .failure
        case .light: .click
        case .medium: .start
        case .heavy: .stop
        case .selection: .click
        }
    }
    #endif
}

public struct HapticsDemo: View {
    public init() {}

    public let haptics = Haptics()

    public var body: some View {
        List {
            #if os(iOS)
            ForEach(Haptics.SignalMobile.allCases, id: \.self) { signal in
                Button(signal.rawValue) {
                    haptics.signalMobile(signal)
                }
            }
            #elseif os(watchOS)
            ForEach(Haptics.SignalWatch.allCases, id: \.self) { signal in
                Button("\(signal.name)") {
                    haptics.signalWatch(signal)
                }
            }
            #endif
        }
    }
}

#Preview {
    HapticsDemo()
}
