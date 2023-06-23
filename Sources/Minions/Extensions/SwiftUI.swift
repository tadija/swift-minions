#if canImport(SwiftUI)

import SwiftUI

// MARK: - Operator overloads

// swiftlint:disable syntactic_sugar
/// - See: https://stackoverflow.com/a/61002589/2165585
func ?? <T>(lhs: Binding<Optional<T>>, rhs: T) -> Binding<T> {
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
            $0.gesture(gesture)
        }
    }
}

// MARK: - View+AnimationCompletion

/// - See: https://www.avanderlee.com/swiftui/withanimation-completion-callback
/// An animatable modifier that is used for observing animations for a given animatable value.
public struct AnimationCompletionObserverModifier<Value>: AnimatableModifier where Value: VectorArithmetic {

    /// While animating, SwiftUI changes the old input value to the new target value using this property.
    /// This value is set to the old value until the animation completes.
    public var animatableData: Value {
        didSet {
            notifyCompletionIfFinished()
        }
    }

    /// The target value for which we're observing. This value is directly set once the animation starts.
    /// During animation, `animatableData` will hold the oldValue and is only updated to the target value
    /// once the animation completes.
    private var targetValue: Value

    /// The completion callback which is called once the animation completes.
    private var completion: () -> Void

    init(observedValue: Value, completion: @escaping () -> Void) {
        self.completion = completion
        animatableData = observedValue
        targetValue = observedValue
    }

    /// Verifies whether the current animation is finished and calls the completion callback if true.
    private func notifyCompletionIfFinished() {
        guard animatableData == targetValue else { return }

        /// Dispatching is needed to take the next runloop for the completion callback.
        DispatchQueue.main.async {
            completion()
        }
    }

    public func body(content: Content) -> some View {
        /// We're not really modifying the view so we can directly return the original input value.
        content
    }
}

public extension View {
    /// Calls the completion handler whenever an animation on the given value completes.
    /// - Parameters:
    ///   - value: The value to observe for animations.
    ///   - completion: The completion callback to call once the animation completes.
    /// - Returns: A modified `View` instance with the observer attached.
    func onAnimationCompleted<Value: VectorArithmetic>(
        for value: Value, completion: @escaping () -> Void
    ) -> ModifiedContent<Self, AnimationCompletionObserverModifier<Value>> {
        modifier(AnimationCompletionObserverModifier(observedValue: value, completion: completion))
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

// MARK: - ObservableObject+Bind

public extension ObservableObject {
    func bind<T>(
        _ keyPath: ReferenceWritableKeyPath<Self, T>,
        animation: Animation? = .none
    ) -> Binding<T> {
        .init(
            get: {
                self[keyPath: keyPath]
            },
            set: { value in
                if let animation = animation {
                    withAnimation(animation) {
                        self[keyPath: keyPath] = value
                    }
                } else {
                    self[keyPath: keyPath] = value
                }
            }
        )
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

// MARK: - iOS Specific

#if os(iOS)

import Combine
import UIKit

// MARK: - KeyboardAdaptive

/// - See: https://gist.github.com/scottmatthewman/722987c9ad40f852e2b6a185f390f88d
public struct KeyboardAdaptive: ViewModifier {
    @State private var currentHeight: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .padding(.bottom, currentHeight)
            .edgesIgnoringSafeArea(currentHeight == 0 ? [] : .bottom)
            .onAppear(perform: subscribeToKeyboardEvents)
    }

    private func subscribeToKeyboardEvents() {
        NotificationCenter.Publisher(
            center: NotificationCenter.default,
            name: UIResponder.keyboardWillShowNotification
        ).compactMap { notification in
            notification.userInfo?["UIKeyboardFrameEndUserInfoKey"] as? CGRect
        }.map { rect in
            rect.height
        }.subscribe(Subscribers.Assign(object: self, keyPath: \.currentHeight))

        NotificationCenter.Publisher(
            center: NotificationCenter.default,
            name: UIResponder.keyboardWillHideNotification
        ).compactMap { _ in
            CGFloat.zero
        }.subscribe(Subscribers.Assign(object: self, keyPath: \.currentHeight))
    }
}

public extension View {
    func keyboardAdaptive() -> some View {
        modifier(KeyboardAdaptive())
    }
}

// MARK: - CornerRadius

/// - See: https://stackoverflow.com/a/58606176/2165585
public struct RoundedCorner: Shape {
    public var radius: CGFloat
    public var corners: UIRectCorner

    public init(
        radius: CGFloat = .infinity,
        corners: UIRectCorner = .allCorners
    ) {
        self.radius = radius
        self.corners = corners
    }

    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

public extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

public extension Edge.Set {
    static let none: Edge.Set = []
}

#endif

#endif
