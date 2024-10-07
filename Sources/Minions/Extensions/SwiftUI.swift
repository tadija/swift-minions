#if canImport(SwiftUI)

import SwiftUI

// MARK: - Operator overloads

// swiftlint:disable syntactic_sugar
/// - See: https://stackoverflow.com/a/61002589/2165585
public func ?? <T>(lhs: Binding<Optional<T>>, rhs: T) -> Binding<T> {
    Binding(
        get: { lhs.wrappedValue ?? rhs },
        set: { lhs.wrappedValue = $0 }
    )
}
// swiftlint:enable syntactic_sugar

// MARK: - View+Notifications

/// - See: https://twitter.com/tadija/status/1311263107247943680
public extension View {
    func onReceive(
        _ name: Notification.Name,
        center: NotificationCenter = .default,
        object: AnyObject? = nil,
        perform action: @escaping (Notification) -> Void
    ) -> some View {
        onReceive(
            center.publisher(for: name, object: object), perform: action
        )
    }
}

// MARK: - View+Condition

/// - See: https://fivestars.blog/swiftui/conditional-modifiers.html
public extension View {
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, modifier: (Self) -> T) -> some View {
        if condition {
            modifier(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func `if`<T: View, F: View>(
        _ condition: Bool,
        if ifModifier: (Self) -> T,
        else elseModifier: (Self) -> F
    ) -> some View {
        if condition {
            ifModifier(self)
        } else {
            elseModifier(self)
        }
    }

    @ViewBuilder
    func ifLet<V, T: View>(_ value: V?, modifier: (Self, V) -> T) -> some View {
        if let value = value {
            modifier(self, value)
        } else {
            self
        }
    }

    /// - See: https://stackoverflow.com/a/71203870/2165585
    @ViewBuilder
    func modify(@ViewBuilder _ transform: (Self) -> (some View)?) -> some View {
        if let view = transform(self), !(view is EmptyView) {
            view
        }
        else {
            self
        }
    }

}

// MARK: - View+Debug

/// - See: https://www.swiftbysundell.com/articles/building-swiftui-debugging-utilities/
public extension View {
    func debugAction(_ closure: () -> Void) -> Self {
        #if DEBUG
        closure()
        #endif
        return self
    }

    func debugLog(_ value: Any) -> Self {
        debugAction {
            debugPrint(value)
        }
    }
}

public extension View {
    func debugModifier<T: View>(_ modifier: (Self) -> T) -> some View {
        #if DEBUG
        return modifier(self)
        #else
        return self
        #endif
    }

    func debugBorder(_ color: Color = .red, width: CGFloat = 1) -> some View {
        debugModifier {
            $0.border(color, width: width)
        }
    }

    func debugBackground(_ color: Color = .red) -> some View {
        debugModifier {
            $0.background(color)
        }
    }

    func debugGesture<G: Gesture>(_ gesture: G) -> some View {
        debugModifier {
            $0.simultaneousGesture(gesture)
        }
    }
}

// MARK: - View+Effects

/// - See: https://www.hackingwithswift.com/plus/swiftui-special-effects/shadows-and-glows
public extension View {
    func glow(color: Color = .red, radius: CGFloat = 20) -> some View {
        shadow(color: color, radius: radius / 3)
            .shadow(color: color, radius: radius / 3)
            .shadow(color: color, radius: radius / 3)
    }

    func innerShadow<S: Shape>(
        using shape: S,
        angle: Angle = .degrees(0),
        color: Color = .black,
        width: CGFloat = 6,
        blur: CGFloat = 6
    ) -> some View {
        let finalX = CGFloat(cos(angle.radians - .pi / 2))
        let finalY = CGFloat(sin(angle.radians - .pi / 2))
        return overlay(
            shape
                .stroke(color, lineWidth: width)
                .offset(x: finalX * width * 0.6, y: finalY * width * 0.6)
                .blur(radius: blur)
                .mask(shape)
        )
    }
}

// MARK: - Geometry+Helpers

public extension GeometryProxy {
    var isPortrait: Bool {
        size.height > size.width
    }

    var isLandscape: Bool {
        size.width > size.height
    }
}

// MARK: - ButtonStyle

/// - See: https://stackoverflow.com/a/58176268/2165585
public struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 2

    var animationIn: Animation? = .none
    var animationOut: Animation? = .default

    public func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(
                configuration.isPressed ? animationIn : animationOut,
                value: configuration.isPressed
            )
    }
}

// MARK: - Custom transition

extension AnyTransition {
    static var verticalScale: AnyTransition {
        .modifier(
            active: VerticalScaleEffect(scale: 0),
            identity: VerticalScaleEffect(scale: 1)
        )
    }
}

public struct VerticalScaleEffect: GeometryEffect {

    public var scale: CGFloat

    public var animatableData: CGFloat {
        get { scale }
        set { scale = newValue }
    }

    public func effectValue(size: CGSize) -> ProjectionTransform {
        let scaleTransform: CGAffineTransform = .init(scaleX: 1, y: scale)
        return ProjectionTransform(scaleTransform)
    }
}

// MARK: - LabelStyle

public extension LabelStyle where Self == VerticalLabelStyle {
    static func vertical(_ spacing: CGFloat = 8) -> Self {
        .init(spacing: spacing)
    }
}

public struct VerticalLabelStyle: LabelStyle {
    var spacing: CGFloat

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .center, spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - PreferenceKey / CGSize

/// - See: https://stackoverflow.com/a/63305935/2165585
public protocol CGSizePreferenceKey: PreferenceKey where Value == CGSize {}

public extension CGSizePreferenceKey {
    static func reduce(value _: inout CGSize, nextValue: () -> CGSize) {
        _ = nextValue()
    }
}

public extension View {
    func onSizeChanged<Key: CGSizePreferenceKey>(
        _ key: Key.Type,
        perform action: @escaping (CGSize) -> Void
    ) -> some View {
        background(GeometryReader { geo in
            Color.clear
                .preference(key: Key.self, value: geo.size)
        })
        .onPreferenceChange(key) { value in
            action(value)
        }
    }
}

// MARK: - PreferenceKey / CGFloat

public protocol CGFloatPreferenceKey: PreferenceKey where Value == CGFloat {}

public extension CGFloatPreferenceKey {
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

public extension View {
    func changePreference<Key: CGFloatPreferenceKey>(
        _ key: Key.Type,
        using closure: @escaping (GeometryProxy) -> CGFloat
    ) -> some View {
        background(GeometryReader { geo in
            Color.clear
                .preference(key: Key.self, value: closure(geo))
        })
    }
}

// MARK: - Image Helpers

#if canImport(UIKit)
public extension Image {
    init(imageData: Data) {
        self = Image(uiImage: .init(data: imageData) ?? .init())
    }
}
public extension UIImage {
    func dataRepresentation() -> Data {
        pngData() ?? .init()
    }
}
#elseif canImport(AppKit)
public extension Image {
    init(imageData: Data) {
        self = Image(nsImage: .init(data: imageData) ?? .init())
    }
}
public extension NSImage {
    func dataRepresentation() -> Data {
        tiffRepresentation ?? .init()
    }
}
#endif

// MARK: - Scalable Font

public extension Text {
    enum ScalableFont {
        case system
        case custom(String)
    }

    func scalableFont(
        _ scalableFont: ScalableFont = .system,
        padding: CGFloat = 0
    ) -> some View {
        font(resolveFont(for: scalableFont))
            .padding(padding)
            .minimumScaleFactor(0.01)
            .lineLimit(1)
    }

    private func resolveFont(for scalableFont: ScalableFont) -> Font {
        switch scalableFont {
        case .system:
            return .system(size: 500)
        case .custom(let name):
            return .custom(name, size: 500)
        }
    }
}

// MARK: - Binding+Setter

/// - See: https://gist.github.com/Amzd/c3015c7e938076fc1e39319403c62950
public extension Binding {
    func didSet(_ didSet: @escaping ((newValue: Value, oldValue: Value)) -> Void) -> Binding<Value> {
        .init(
            get: {
                wrappedValue
            },
            set: { newValue in
                let oldValue = wrappedValue
                wrappedValue = newValue
                didSet((newValue, oldValue))
            }
        )
    }

    func willSet(_ willSet: @escaping ((newValue: Value, oldValue: Value)) -> Void) -> Binding<Value> {
        .init(
            get: {
                wrappedValue
            },
            set: { newValue in
                willSet((newValue, wrappedValue))
                wrappedValue = newValue
            }
        )
    }
}

/// - See: https://stackoverflow.com/a/76401269/2165585
public extension Binding {
    func isNotNil<T>() -> Binding<Bool> where Value == T? {
        .init(get: {
            wrappedValue != nil
        }, set: { _ in
            wrappedValue = nil
        })
    }
}

public extension Edge.Set {
    static let none: Edge.Set = []
}

#endif
