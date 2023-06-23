#if os(iOS) || os(tvOS)

import UIKit

// MARK: - Auto Layout Helpers

extension UIView: Anchorable {}
extension UILayoutGuide: Anchorable {}

public protocol Anchorable {
    var leadingAnchor: NSLayoutXAxisAnchor { get }
    var trailingAnchor: NSLayoutXAxisAnchor { get }
    var leftAnchor: NSLayoutXAxisAnchor { get }
    var rightAnchor: NSLayoutXAxisAnchor { get }
    var topAnchor: NSLayoutYAxisAnchor { get }
    var bottomAnchor: NSLayoutYAxisAnchor { get }
    var widthAnchor: NSLayoutDimension { get }
    var heightAnchor: NSLayoutDimension { get }
    var centerXAnchor: NSLayoutXAxisAnchor { get }
    var centerYAnchor: NSLayoutYAxisAnchor { get }
}

public extension Anchorable {
    var leading: NSLayoutXAxisAnchor { leadingAnchor }
    var trailing: NSLayoutXAxisAnchor { trailingAnchor }
    var left: NSLayoutXAxisAnchor { leftAnchor }
    var right: NSLayoutXAxisAnchor { rightAnchor }
    var top: NSLayoutYAxisAnchor { topAnchor }
    var bottom: NSLayoutYAxisAnchor { bottomAnchor }
    var width: NSLayoutDimension { widthAnchor }
    var height: NSLayoutDimension { heightAnchor }
    var centerX: NSLayoutXAxisAnchor { centerXAnchor }
    var centerY: NSLayoutYAxisAnchor { centerYAnchor }

    func constrainHorizontally<T: Anchorable>(
        to anchor: T,
        leadingInset: CGFloat = 0,
        trailingInset: CGFloat = 0
    ) -> [NSLayoutConstraint] {
        [
            leading.constraint(equalTo: anchor.leading, constant: leadingInset),
            anchor.trailing.constraint(equalTo: trailing, constant: trailingInset)
        ]
    }

    func constrainVertically<T: Anchorable>(
        to anchor: T,
        topInset: CGFloat = 0,
        bottomInset: CGFloat = 0
    ) -> [NSLayoutConstraint] {
        [
            top.constraint(equalTo: anchor.top, constant: topInset),
            anchor.bottom.constraint(equalTo: bottom, constant: bottomInset)
        ]
    }

    func constrainEdges<T: Anchorable>(
        to anchor: T,
        insets: UIEdgeInsets = .zero
    ) -> [NSLayoutConstraint] {
        let h = constrainHorizontally(
            to: anchor,
            leadingInset: insets.left,
            trailingInset: insets.right
        )
        let v = constrainVertically(
            to: anchor,
            topInset: insets.top,
            bottomInset: insets.bottom
        )
        return h + v
    }

    func constrainCenter<T: Anchorable>(to anchor: T) -> [NSLayoutConstraint] {
        [
            centerX.constraint(equalTo: anchor.centerX),
            centerY.constraint(equalTo: anchor.centerY)
        ]
    }

    func constrainSize(to size: CGSize) -> [NSLayoutConstraint] {
        [
            width.constraint(equalToConstant: size.width),
            height.constraint(equalToConstant: size.height)
        ]
    }
}

public extension UIView {
    func addSubview(_ view: UIView, constraints: NSLayoutConstraint...) {
        addSubview(view, constraints: Array(constraints))
    }

    func addSubview(_ view: UIView, constraints: [NSLayoutConstraint]) {
        addSubview(view)
        view.activateConstraints(constraints)
    }

    func addSubviews(_ constraints: [UIView: [NSLayoutConstraint]]) {
        constraints.keys.forEach { addSubview($0) }
        constraints.forEach { $0.activateConstraints($1) }
    }

    func activateConstraints(_ constraints: NSLayoutConstraint...) {
        activateConstraints(Array(constraints))
    }

    func activateConstraints(_ constraints: [NSLayoutConstraint]) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(constraints)
    }
}

public extension UIView {
    func embedToEdges(_ view: UIView, insets: UIEdgeInsets = .zero) {
        addSubview(view, constraints: view.constrainEdges(to: self, insets: insets))
    }

    func embedAtCenter(_ view: UIView) {
        addSubview(view, constraints: view.constrainCenter(to: self))
    }

    func makeCircle() {
        layer.cornerRadius = bounds.width / 2
        clipsToBounds = true
    }
}

public extension NSLayoutConstraint {
    func prioritized(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}

public extension UIEdgeInsets {
    init(_ size: CGFloat) {
        self.init(top: size, left: size, bottom: size, right: size)
    }
}

public extension UIStackView {
    func addArrangedSubview(_ view: UIView, constraints: NSLayoutConstraint...) {
        addArrangedSubview(view, constraints: Array(constraints))
    }

    func addArrangedSubview(_ view: UIView, constraints: [NSLayoutConstraint]) {
        addArrangedSubview(view)
        view.activateConstraints(constraints)
    }

    func addArrangedSubviews(_ views: UIView...) {
        views.forEach { addArrangedSubview($0) }
    }

    func addArrangedSubviews(_ views: [UIView]) {
        views.forEach { addArrangedSubview($0) }
    }

    func reverseArrangedSubviews() {
        let reversed: [UIView] = arrangedSubviews.reversed()
        arrangedSubviews.forEach({ removeArrangedSubview($0) })
        addArrangedSubviews(reversed)
    }

    func embedWithRelativeMargins(_ view: UIView, padding: UIEdgeInsets? = nil) {
        isLayoutMarginsRelativeArrangement = true
        addArrangedSubview(view)
        if let padding = padding {
            layoutMargins = padding
        }
    }
}

public extension UIViewController {
    @discardableResult
    func embed<T: UIViewController>(_ child: T) -> T {
        add(child, constraints: child.view.constrainEdges(to: view))
    }

    /// - See: https://www.swiftbysundell.com/posts/using-child-view-controllers-as-plugins-in-swift
    @discardableResult
    func add<T: UIViewController>(
        _ child: T,
        into container: UIView? = nil,
        constraints: [NSLayoutConstraint]? = nil
    ) -> T {
        let parentView = container ?? view ?? UIView()
        addChild(child)
        parentView.addSubview(child.view)
        if let constraints = constraints {
            child.view.activateConstraints(constraints)
        }
        child.didMove(toParent: self)
        return child
    }

    func remove() {
        guard parent != nil else {
            return
        }
        willMove(toParent: nil)
        removeFromParent()
        view.removeFromSuperview()
    }
}

// MARK: - Nib & Storyboard Helpers

/// - See: https://github.com/alisoftware/Reusable
extension UIView {
    public static func loadFromNib() -> Self {
        guard let view = nib
            .instantiate(withOwner: nil, options: nil)
            .first as? Self
        else {
            fatalError("Failed to load view from nib: \(nibName)")
        }
        return view
    }

    public func loadFromNib() {
        guard let view = Self.nib
            .instantiate(withOwner: self, options: nil)
            .first as? UIView
        else {
            fatalError("Failed to load view from nib: \(Self.nibName)")
        }
        embedToEdges(view)
    }

    public static var typeName: String {
        String(describing: self)
    }

    @objc
    open class var nibName: String {
        typeName
    }

    @objc
    open class var nib: UINib {
        UINib(nibName: nibName, bundle: Bundle(for: self))
    }
}

extension UIViewController {
    public static func loadFromStoryboard() -> Self {
        let vc: UIViewController?
        let storyboard = UIStoryboard(name: storyboardName, bundle: Bundle(for: self))
        if let identifier = storyboardIdentifier {
            vc = storyboard.instantiateViewController(withIdentifier: identifier)
        } else {
            vc = storyboard.instantiateInitialViewController()
        }
        guard let storyboardVC = vc as? Self else {
            fatalError("Failed to load from storyboard: \(String(describing: self))")
        }
        return storyboardVC
    }

    @objc
    open class var storyboardName: String {
        String(describing: self)
    }

    @objc
    open class var storyboardIdentifier: String? {
        nil
    }
}

#endif
