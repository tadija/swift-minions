#if os(macOS)

import AppKit
import SwiftUI

public extension NSWindow {
    static func open<T: View>(
        _ title: String = "",
        size: CGSize = .init(width: 400, height: 300),
        styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable],
        @ViewBuilder _ content: () -> T
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(
            rootView: content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.title = title
        window.isReleasedWhenClosed = false
    }
}

#endif
