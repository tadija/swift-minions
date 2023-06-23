#if canImport(Foundation)

import Foundation

// MARK: - Top Level Helpers

/// Makes sure no other thread reenters the closure before the one running has not returned
/// - See: https://stackoverflow.com/a/61458763/2165585
@discardableResult
public func synchronized<T>(_ lock: AnyObject, closure: () -> T) -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return closure()
}

// MARK: - NotificationToken

/// Wraps the observer token received from
/// `NotificationCenter.addObserver(forName:object:queue:using:)`
/// and unregisters it in `deinit`.
/// - See: https://oleb.net/blog/2018/01/notificationcenter-removeobserver/
public final class NotificationToken: NSObject {
    let notificationCenter: NotificationCenter
    let token: Any

    init(notificationCenter: NotificationCenter = .default, token: Any) {
        self.notificationCenter = notificationCenter
        self.token = token
    }

    deinit {
        notificationCenter.removeObserver(token)
    }
}

public extension NotificationCenter {
    /// Convenience wrapper for `addObserver(forName:object:queue:using:)`
    /// that returns our custom `NotificationToken`.
    func observe(
        name: NSNotification.Name?,
        object: Any? = nil,
        queue: OperationQueue? = .main,
        then completion: @escaping (Notification) -> Void
    ) -> NotificationToken {
        let token = addObserver(
            forName: name,
            object: object,
            queue: queue,
            using: completion
        )
        return NotificationToken(notificationCenter: self, token: token)
    }
}

// MARK: - ObjectAssociation

/// Helper class for adding stored properties with extension.
/// - See: https://stackoverflow.com/a/43056053/2165585
public final class ObjectAssociation<T: AnyObject> {

    private let policy: objc_AssociationPolicy

    /// - Parameter policy: An association policy that will be used when linking objects.
    public init(policy: objc_AssociationPolicy = .OBJC_ASSOCIATION_RETAIN_NONATOMIC) {
        self.policy = policy
    }

    /// Accesses associated object.
    /// - Parameter index: An object whose associated object is to be accessed.
    public subscript(index: AnyObject) -> T? {
        get {
            // swiftlint:disable force_cast
            objc_getAssociatedObject(
                index,
                Unmanaged.passUnretained(self).toOpaque()
            ) as! T?
            // swiftlint:enable force_cast
        }
        set {
            objc_setAssociatedObject(
                index,
                Unmanaged.passUnretained(self).toOpaque(),
                newValue,
                policy
            )
        }
    }

}

#endif
