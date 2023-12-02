#if canImport(SwiftUI)

import SwiftUI

// MARK: - Line

public struct Line: Shape {
    public let x1: CGFloat
    public let y1: CGFloat
    public let x2: CGFloat
    public let y2: CGFloat

    public init(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x2, y: y2))
        return path
    }
}

public struct LineTop: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

public struct LineLeft: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

public struct LineBottom: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

public struct LineRight: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

// MARK: - Pie

/// - See: https://cs193p.sites.stanford.edu
public struct Pie: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var clockwise: Bool = false

    public init(startAngle: Angle, endAngle: Angle, clockwise: Bool) {
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.clockwise = clockwise
    }

    public var animatableData: AnimatablePair<Double, Double> {
        get {
            AnimatablePair(startAngle.radians, endAngle.radians)
        }
        set {
            startAngle = Angle.radians(newValue.first)
            endAngle = Angle.radians(newValue.second)
        }
    }

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let start = CGPoint(
            x: center.x + radius * cos(CGFloat(startAngle.radians)),
            y: center.y + radius * sin(CGFloat(startAngle.radians))
        )

        var p = Path()
        p.move(to: center)
        p.addLine(to: start)
        p.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )
        p.addLine(to: center)
        return p
    }
}

// MARK: - Placeholder

public struct Placeholder<T: View>: View {
    var lineWidth: CGFloat
    var dash: [CGFloat]
    var color: Color
    var content: T

    public init(
        lineWidth: CGFloat = 0.5,
        dash: [CGFloat] = [8],
        color: Color = .secondary,
        @ViewBuilder content: () -> T
    ) {
        self.lineWidth = lineWidth
        self.dash = dash
        self.color = color
        self.content = content()
    }

    public init(_ text: String = "placeholder") where T == Text {
        self.init {
            Text(text)
        }
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: lineWidth, dash: dash))
                .foregroundColor(color)

            content
        }
    }
}

// MARK: - Polygon

/// - See: https://swiftui-lab.com/swiftui-animations-part1
public struct Polygon: Shape {
    var sides: Double
    var scale: Double
    var drawVertexLines: Bool

    public init(sides: Double, scale: Double, drawVertexLines: Bool = false) {
        self.sides = sides
        self.scale = scale
        self.drawVertexLines = drawVertexLines
    }

    public var animatableData: AnimatablePair<Double, Double> {
        get {
            AnimatablePair(sides, scale)
        }
        set {
            sides = newValue.first
            scale = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        let hypotenuse = Double(min(rect.size.width, rect.size.height)) / 2.0 * scale
        let center = CGPoint(x: rect.size.width / 2.0, y: rect.size.height / 2.0)

        var path = Path()

        let extra: Int = sides != Double(Int(sides)) ? 1 : 0

        var vertex: [CGPoint] = []

        for i in 0..<Int(sides) + extra {
            let angle = (Double(i) * (360.0 / sides)) * (Double.pi / 180)

            // calculate vertex
            let pt = CGPoint(
                x: center.x + CGFloat(cos(angle) * hypotenuse),
                y: center.y + CGFloat(sin(angle) * hypotenuse)
            )

            vertex.append(pt)

            if i == 0 {
                path.move(to: pt) // move to first vertex
            } else {
                path.addLine(to: pt) // draw line to next vertex
            }
        }

        path.closeSubpath()

        if drawVertexLines {
            drawVertexLines(path: &path, vertex: vertex, n: 0)
        }

        return path
    }

    private func drawVertexLines(path: inout Path, vertex: [CGPoint], n: Int) {
        if (vertex.count - n) < 3 { return }

        for i in (n + 2)..<min(n + (vertex.count - 1), vertex.count) {
            path.move(to: vertex[n])
            path.addLine(to: vertex[i])
        }

        drawVertexLines(path: &path, vertex: vertex, n: n + 1)
    }
}

// MARK: - StickyHeader

/// - See: https://trailingclosure.com/sticky-header
public struct StickyHeader<Content: View>: View {
    public var minHeight: CGFloat
    public var content: Content

    public init(
        minHeight: CGFloat = 200,
        @ViewBuilder content: () -> Content
    ) {
        self.minHeight = minHeight
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geo in
            if geo.frame(in: .global).minY <= 0 {
                content.frame(
                    width: geo.size.width,
                    height: geo.size.height,
                    alignment: .center
                )
            } else {
                content
                    .offset(y: -geo.frame(in: .global).minY)
                    .frame(
                        width: geo.size.width,
                        height: geo.size.height + geo.frame(in: .global).minY
                    )
            }
        }.frame(minHeight: minHeight)
    }
}

// MARK: - Stripes

#if os(iOS) || os(tvOS) || os(visionOS)
import CoreImage.CIFilterBuiltins

/// - See: https://stackoverflow.com/a/63166881/2165585
extension CGImage {
    static func generateStripePattern(
        colors: (UIColor, UIColor) = (.clear, .black),
        width: CGFloat = 6,
        ratio: CGFloat = 1
    ) -> CGImage? {

        let context = CIContext()
        let stripes = CIFilter.stripesGenerator()
        stripes.color0 = CIColor(color: colors.0)
        stripes.color1 = CIColor(color: colors.1)
        stripes.width = Float(width)
        stripes.center = CGPoint(x: 1 - width * ratio, y: 0)
        let size = CGSize(width: width, height: 1)

        guard
            let stripesImage = stripes.outputImage,
            let image = context.createCGImage(stripesImage, from: CGRect(origin: .zero, size: size))
        else { return nil }
        return image
    }
}

public extension Shape {
    func stripes(angle: Double = 45) -> AnyView {
        guard
            let stripePattern = CGImage.generateStripePattern()
        else { return AnyView(self)}

        return AnyView(
            Rectangle()
                .fill(
                    ImagePaint(
                        image: Image(decorative: stripePattern, scale: 1.0)
                    )
                )
                .scaleEffect(2)
                .rotationEffect(.degrees(angle))
                .clipShape(self)
        )
    }
}
#endif

// MARK: - ToggleAsync

public struct ToggleAsync<T: View>: View {
    @Binding var isOn: Bool
    var label: () -> T
    var onValueChanged: ((Bool) -> Void)?

    public init(
        isOn: Binding<Bool>,
        label: @escaping () -> T,
        onValueChanged: ((Bool) -> Void)? = nil
    ) {
        _isOn = isOn
        self.label = label
        self.onValueChanged = onValueChanged
    }

    public var body: some View {
        Toggle(
            isOn: $isOn
                .didSet { newValue, oldValue in
                    if newValue != oldValue {
                        onValueChanged?(newValue)
                    }
                },
            label: label
        )
    }
}

#if os(iOS)

// MARK: - SafeAreaView

struct SafeAreaView<T: View>: View {
    var edges: Edge.Set
    var content: () -> T

    @State private var safeArea: UIEdgeInsets = UIWindow.safeArea

    var body: some View {
        content()
            .padding(.top, edges.contains(.top) ? safeArea.top : 0)
            .padding(.bottom, edges.contains(.bottom) ? safeArea.bottom : 0)
            .padding(.leading, edges.contains(.leading) ? safeArea.left : 0)
            .padding(.trailing, edges.contains(.trailing) ? safeArea.right : 0)

            .onReceive(UIDevice.orientationDidChangeNotification) { _ in
                safeArea = UIWindow.safeArea
            }
    }
}

struct SafeAreaViewModifier: ViewModifier {
    var edges: Edge.Set

    func body(content: Content) -> some View {
        SafeAreaView(edges: edges) {
            content
        }
    }
}

public extension View {
    func edgesRespectingSafeArea(_ edges: Edge.Set) -> some View {
        modifier(SafeAreaViewModifier(edges: edges))
    }
}

#endif

#endif
