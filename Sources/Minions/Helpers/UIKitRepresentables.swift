#if canImport(SwiftUI)
import SwiftUI
#endif

#if os(iOS)

// MARK: - Share Sheet

/// - See: https://developer.apple.com/forums/thread/123951
public struct ShareSheet: UIViewControllerRepresentable {
    public typealias Callback = (
        _ activityType: UIActivity.ActivityType?,
        _ completed: Bool,
        _ returnedItems: [Any]?,
        _ error: Error?
    ) -> Void

    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]?
    public let excludedActivityTypes: [UIActivity.ActivityType]?
    public let callback: Callback?

    public init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil,
        excludedActivityTypes: [UIActivity.ActivityType]? = nil,
        callback: Callback? = nil
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.excludedActivityTypes = excludedActivityTypes
        self.callback = callback
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = callback
        return controller
    }

    public func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Image Picker

public struct ImagePicker: UIViewControllerRepresentable {

    var sourceType: UIImagePickerController.SourceType

    @Binding var image: UIImage?

    var callback: Callback?

    public typealias Callback = (
        _ picker: UIImagePickerController,
        _ info: [UIImagePickerController.InfoKey: Any]
    ) -> Void

    public init(
        _ sourceType: UIImagePickerController.SourceType = .photoLibrary,
        image: Binding<UIImage?>? = .constant(nil),
        callback: Callback? = nil
    ) {
        self.sourceType = sourceType
        _image = image ?? .constant(nil)
        self.callback = callback
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = false
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        return imagePicker
    }

    public func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        public func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.originalImage] as? UIImage

            if let callback = parent.callback {
                callback(picker, info)
            } else {
                picker.dismiss(animated: true)
            }
        }
    }
}

// MARK: - Photo Picker

import PhotosUI

public struct PhotoPicker: UIViewControllerRepresentable {

    public static var defaultConfig: PHPickerConfiguration {
        var config = PHPickerConfiguration()
        config.filter = .images
        return config
    }

    let config: PHPickerConfiguration

    @Binding var image: UIImage?

    var callback: Callback?

    public typealias Callback = (
        _ picker: PHPickerViewController,
        _ results: [PHPickerResult]
    ) -> Void

    public init(
        _ config: PHPickerConfiguration = Self.defaultConfig,
        image: Binding<UIImage?>? = .constant(nil),
        callback: Callback? = nil
    ) {
        self.config = config
        _image = image ?? .constant(nil)
        self.callback = callback
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        public func picker(
            _ picker: PHPickerViewController,
            didFinishPicking results: [PHPickerResult]
        ) {
            Task {
                parent.image = await getImage(from: results)

                if parent.callback == nil {
                    DispatchQueue.main.async {
                        picker.dismiss(animated: true)
                    }
                }
            }

            if let callback = parent.callback {
                callback(picker, results)
            }
        }

        private func getImage(from results: [PHPickerResult]) async -> UIImage? {
            let provider = results.first?.itemProvider
            let canLoadImage = provider?.canLoadObject(ofClass: UIImage.self) ?? false

            guard canLoadImage else {
                return nil
            }

            return await withCheckedContinuation { continuation in
                provider?.loadObject(ofClass: UIImage.self) { image, _ in
                    continuation.resume(with: .success(image as? UIImage))
                }
            }
        }
    }
}

// MARK: - Safari View

import SafariServices

/// - See: https://stackoverflow.com/a/75376581/2165585
public struct SafariView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss

    let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = .tintColor
        vc.delegate = context.coordinator
        return vc
    }

    public func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}

    public final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        var dismissAction: DismissAction?

        public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            dismissAction?()
        }
    }

    public func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.dismissAction = dismiss
        return coordinator
    }
}

// MARK: - Visual Effect

public struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect

    public init(_ effect: UIVisualEffect = UIBlurEffect(style: .regular)) {
        self.effect = effect
    }

    public func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView()
    }

    public func updateUIView(_ view: UIVisualEffectView, context: Context) {
        view.effect = effect
    }
}

#elseif os(macOS)

// MARK: - Visual Effect

public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    public init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        NSVisualEffectView()
    }

    public func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}

#endif
