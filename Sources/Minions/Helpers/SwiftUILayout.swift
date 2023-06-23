#if canImport(SwiftUI)

import SwiftUI

// MARK: - Layout Helpers

public struct LayoutFill<T: View>: View {
    let color: Color
    let alignment: Alignment
    var content: T

    public init(
        _ color: Color = .clear,
        alignment: Alignment = .center,
        @ViewBuilder content: () -> T
    ) {
        self.color = color
        self.alignment = alignment
        self.content = content()
    }

    public var body: some View {
        color.overlay(content, alignment: alignment)
    }
}

public struct LayoutCenter<T: View>: View {
    let axis: Axis
    var content: T

    public init(_ axis: Axis, @ViewBuilder content: () -> T) {
        self.axis = axis
        self.content = content()
    }

    public var body: some View {
        switch axis {
        case .horizontal:
            HStack(spacing: 0) { centeredContent }
        case .vertical:
            VStack(spacing: 0) { centeredContent }
        }
    }

    @ViewBuilder
    private var centeredContent: some View {
        Spacer()
        content
        Spacer()
    }
}

public struct LayoutHalf<T: View>: View {
    let edge: Edge
    var content: T

    public init(_ edge: Edge, @ViewBuilder content: () -> T) {
        self.edge = edge
        self.content = content()
    }

    public var body: some View {
        switch edge {
        case .top:
            VStack(spacing: 0) {
                content
                Color.clear
            }
        case .bottom:
            VStack(spacing: 0) {
                Color.clear
                content
            }
        case .leading:
            HStack(spacing: 0) {
                content
                Color.clear
            }
        case .trailing:
            HStack(spacing: 0) {
                Color.clear
                content
            }
        }
    }
}

public struct LayoutAlign<T: View>: View {
    let alignment: Alignment
    var content: T

    public init(_ alignment: Alignment, @ViewBuilder content: () -> T) {
        self.alignment = alignment
        self.content = content()
    }

    public var body: some View {
        switch alignment {
        case .top:
            Top { content }
        case .bottom:
            Bottom { content }
        case .leading:
            Leading { content }
        case .trailing:
            Trailing { content }
        case .topLeading:
            Top { Leading { content } }
        case .topTrailing:
            Top { Trailing { content } }
        case .bottomLeading:
            Bottom { Leading { content } }
        case .bottomTrailing:
            Bottom { Trailing { content } }
        default:
            fatalError("\(alignment) is not supported")
        }
    }

    private struct Top<T: View>: View {
        var content: () -> T
        var body: some View {
            VStack(spacing: 0) {
                content()
                Spacer()
            }
        }
    }

    private struct Bottom<T: View>: View {
        var content: () -> T
        var body: some View {
            VStack(spacing: 0) {
                Spacer()
                content()
            }
        }
    }

    private struct Leading<T: View>: View {
        var content: () -> T
        var body: some View {
            HStack(spacing: 0) {
                content()
                Spacer()
            }
        }
    }

    private struct Trailing<T: View>: View {
        var content: () -> T
        var body: some View {
            HStack(spacing: 0) {
                Spacer()
                content()
            }
        }
    }
}

#endif
