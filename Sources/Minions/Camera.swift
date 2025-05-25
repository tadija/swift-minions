#if os(iOS) || os(macOS)

@preconcurrency
import AVFoundation
import SwiftUI

// MARK: - Camera

/// Simple wrapper around system Camera API (`AVCaptureSession`).
///
/// Provides capture device preview stream, option to customize session configuration,
/// taking photos using custom settings, zooming, toggling back / front camera etc.
///
/// For usage example, see provided `Camera.CapturePreview` view.
///
@Observable
public final class Camera: @unchecked Sendable {

    /// Used to initialize `Camera` object.
    public enum Device {
        /// default back video device
        case back
        /// default front video device
        case front
        /// custom device
        case custom(AVCaptureDevice?)

        /// Capture device.
        var captureDevice: AVCaptureDevice? {
            switch self {
            case .back:
                return .default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .back
                )
            case .front:
                return .default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .front
                )
            case .custom(let customDevice):
                return customDevice
            }
        }
    }

    /// Latest image from capture preview stream.
    public var previewImage: Image?

    /// Toggle this property to pause / unpause preview stream.
    /// When camera view is not on screen, preview should be paused.
    public var isPreviewPaused = false

    /// Async stream of capture device preview images.
    @ObservationIgnored
    public private(set) lazy var previewStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            session.addToPreviewStream = { ciImage in
                if !self.isPreviewPaused {
                    continuation.yield(ciImage)
                }
            }
        }
    }()

    /// Async stream of captured photos.
    @ObservationIgnored
    public private(set) lazy var photoStream: AsyncStream<AVCapturePhoto> = {
        AsyncStream { continuation in
            session.addToPhotoStream = { photo in
                continuation.yield(photo)
            }
        }
    }()

    /// Authorization status for capturing media.
    public var authStatus: AVAuthorizationStatus {
        session.authStatus
    }

    /// Camera device used for capturing.
    public var device: AVCaptureDevice? {
        session.captureDevice
    }

    /// Flag which indicates if capture session is currently running.
    public var isRunning: Bool {
        session.isRunning
    }

    /// Provide custom session configuration using this closure.
    /// After a default configuration of device inputs and outputs,
    /// this closure will be called before commiting configuration.
    public var customSessionConfiguration: ((AVCaptureSession) -> Void)? {
        didSet {
            session.customConfiguration = { [weak self] session in
                self?.customSessionConfiguration?(session)
            }
        }
    }

    private let session: CameraSession

    /// Creates `Camera` instance.
    /// - Parameter device: device used in capture session.
    public init(_ device: Device = .back) {
        session = CameraSession(captureDevice: device.captureDevice)
    }

}

// MARK: - Views

extension Camera {

    /// View which displays capture preview stream.
    ///
    /// Usage example:
    ///
    ///     struct CameraView: View {
    ///         @State var camera = Camera()
    ///
    ///         public var body: some View {
    ///             Camera.CapturePreview()
    ///                 .environment(camera)
    ///                 .overlay(alignment: .bottom) {
    ///                     Button("CAPTURE") {
    ///                         Task {
    ///                             let photo = try await camera.takePhoto()
    ///                             logWrite("captured photo: \(photo)")
    ///                         }
    ///                     }
    ///                     .buttonStyle(.borderedProminent)
    ///                 }
    ///                 .task {
    ///                     try? await camera.start()
    ///                 }
    ///         }
    ///     }
    ///
    public struct CapturePreview: View {
        @Environment(Camera.self) var camera: Camera

        public init() {}

        @State private var image: Image?

        public var body: some View {
            GeometryReader { g in
                if let preview = camera.previewImage {
                    preview.resizable().scaledToFill()
                        .frame(width: g.size.width, height: g.size.height)
                } else if let image {
                    image.resizable().scaledToFill()
                        .frame(width: g.size.width, height: g.size.height)
                        .overlay { VisualEffectView() }
                }
            }
            .onChange(of: camera.previewImage) { _, newValue in
                if newValue != nil {
                    image = newValue
                }
            }
        }
    }
}

// MARK: - Errors

/// Errors related to `Camera`.
public enum CameraError: Error {

    /// failed to access video input device
    case captureDeviceFailure

    /// failed to add input
    case inputFailure(String)

    /// failed to add output
    case outputFailure(String)

    /// permission restricted or denied
    case permissionFailure

    /// invalid image data
    case invalidImage

    /// torch is not available
    case torchUnavailable

    /// torch mode not supported
    case torchModeNotSupported
}

// MARK: - API

extension Camera {

    // MARK: Session

    /// Configures and starts the capture session and preview stream.
    public func start() async throws {
        guard !isRunning else { return }

        try await session.start()

        Task { await handlePreviewStream() }
    }

    /// Stops current capture session.
    public func stop() async {
        guard isRunning else { return }

        await session.stop()

        await MainActor.run { previewImage = nil }
    }

    // MARK: Device

    /// Update capture device for the current session or toggle between back and front camera.
    public func updateDevice(_ device: AVCaptureDevice? = nil) async throws {
        await MainActor.run {
            isPreviewPaused = true
            previewImage = nil
        }

        var nextDevice: AVCaptureDevice?
        switch self.device {
        case Device.back.captureDevice:
            nextDevice = Device.front.captureDevice
        case Device.front.captureDevice:
            nextDevice = Device.back.captureDevice
        default:
            nextDevice = Device.back.captureDevice
        }

        try await session.switchToDevice(device ?? nextDevice)

        await MainActor.run {
            isPreviewPaused = false
        }
    }

    #if os(iOS)

    // MARK: Zoom

    /// Set `videoZoomFactor` on `device`
    public func setZoomFactor(_ factor: CGFloat) throws {
        guard let device else { throw CameraError.captureDeviceFailure }
        guard factor != zoomFactor else { return }

        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        let newFactor = max(zoomFactorMin, min(factor, zoomFactorMax))
        logWrite("update zoom factor from: \(zoomFactor) to: \(newFactor)")
        device.videoZoomFactor = newFactor
    }

    /// Current zoom factor
    public var zoomFactor: CGFloat {
        device?.videoZoomFactor ?? 1
    }

    /// Minimum zoom factor
    public var zoomFactorMin: CGFloat {
        device?.minAvailableVideoZoomFactor ?? 1
    }

    /// Maximum zoom factor
    public var zoomFactorMax: CGFloat {
        device?.maxAvailableVideoZoomFactor ?? 1
    }

    #endif

    // MARK: Torch

    /// Sets `TorchMode` if torch is available.
    /// - Parameters:
    ///   - mode: Constants to specify the capture device’s torch mode.
    ///   - level: This value must be a floating-point number between 0.0 and 1.0.
    public func setTorchMode(
        _ mode: AVCaptureDevice.TorchMode,
        level: Float = AVCaptureDevice.maxAvailableTorchLevel
    ) throws {
        guard let device else { throw CameraError.captureDeviceFailure }
        guard device.hasTorch, device.isTorchAvailable else { throw CameraError.torchUnavailable }

        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if device.isTorchModeSupported(mode) {
            device.torchMode = mode
        } else {
            throw CameraError.torchModeNotSupported
        }

        if mode == .on {
            try device.setTorchModeOn(level: level)
        }
    }

    /// Toggles torch between `.on` and `.off` states.
    public func toggleTorch() throws {
        guard let device else { throw CameraError.captureDeviceFailure }
        try setTorchMode(device.isTorchActive ? .off : .on)
    }

    // MARK: Photo

    /// Convenience method for taking `ACCapturePhoto` asynchronously.
    public func takePhoto(using settings: AVCapturePhotoSettings = .init()) async throws -> AVCapturePhoto {
        try await withCheckedThrowingContinuation { continuation in
            session.photoContinuations.append(continuation)
            capturePhoto(using: settings)
        }
    }

    /// Initiates a photo capture using the specified settings.
    /// By calling this method, captured photo will be added to the `photoStream`.
    public func capturePhoto(using settings: AVCapturePhotoSettings = .init()) {
        session.capturePhoto(using: settings)
    }

    // MARK: Helpers

    private func handlePreviewStream() async {
        let previewImageStream = previewStream
            .compactMap {
                self.makePreviewImage(from: $0)
            }

        for await image in previewImageStream {
            Task { @MainActor in
                previewImage = image
            }
        }
    }

    private func makePreviewImage(from ciImage: CIImage) -> Image? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}

// MARK: - CameraSession

private final class CameraSession: AVCaptureSession, @unchecked Sendable {

    var authStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    var captureDevice: AVCaptureDevice?

    var customConfiguration: ((AVCaptureSession) -> Void)?

    var addToPreviewStream: ((CIImage) -> Void)?
    var addToPhotoStream: ((AVCapturePhoto) -> Void)?

    var photoContinuations: [CheckedContinuation<AVCapturePhoto, Error>] = []

    private let queue = DispatchQueue(label: "minions.camera.session-queue")

    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()

    init(captureDevice: AVCaptureDevice?) {
        super.init()

        self.captureDevice = captureDevice
    }
}

private extension CameraSession {

    // MARK: API

    func configure() throws {
        // check device
        guard let captureDevice else { throw CameraError.captureDeviceFailure }
        logWrite("capture session configure: \(captureDevice.localizedName)")

        // begin & commit
        beginConfiguration()
        defer { commitConfiguration() }

        // clear inputs & outputs
        inputs.forEach({ removeInput($0) })
        outputs.forEach({ removeOutput($0) })

        // add device input
        let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
        guard canAddInput(deviceInput) else { throw CameraError.inputFailure(deviceInput.description) }
        addInput(deviceInput)

        // add video output
        guard canAddOutput(videoOutput) else { throw CameraError.outputFailure(videoOutput.description) }
        let videoOutputQueue = DispatchQueue(label: "minions.camera.video-queue")
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        addOutput(videoOutput)

        // add photo output
        guard canAddOutput(photoOutput) else { throw CameraError.outputFailure(photoOutput.description) }
        addOutput(photoOutput)

        updateVideoOutputConnection()

        customConfiguration?(self)
    }

    func start() async throws {
        switch authStatus {
        case .notDetermined:
            logWrite("camera access not determined")
            await AVCaptureDevice.requestAccess(for: .video)
            try await start()
        case .restricted, .denied:
            logWrite("camera access restricted / denied")
            throw CameraError.permissionFailure
        case .authorized:
            try await withCheckedThrowingContinuation { continuation in
                queue.async { [unowned self] in
                    do {
                        try configure()
                        startRunning()
                        logWrite("capture session started")
                        continuation.resume()
                    } catch {
                        logWrite("capture session error: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
        @unknown default:
            logWrite("camera access unknown")
            throw CameraError.permissionFailure
        }
    }

    func stop() async {
        await withCheckedContinuation { continunation in
            queue.async { [unowned self] in
                self.stopRunning()
                logWrite("capture session stopped")
                continunation.resume()
            }
        }
    }

    func switchToDevice(_ device: AVCaptureDevice?) async throws {
        guard let device else { throw CameraError.captureDeviceFailure }

        try await withCheckedThrowingContinuation { continuation in
            queue.async { [unowned self] in
                do {
                    try updateSessionForCaptureDevice(device)
                    captureDevice = device
                    continuation.resume()
                    logWrite("using capture device: \(device.localizedName)")
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func capturePhoto(using settings: AVCapturePhotoSettings) {
        queue.async {
            self.updatePhotoOutputConnection()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: Helpers

    func updateSessionForCaptureDevice(_ device: AVCaptureDevice) throws {
        beginConfiguration()
        defer { commitConfiguration() }

        for input in inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                removeInput(deviceInput)
            }
        }

        let deviceInput = try AVCaptureDeviceInput(device: device)
        if !inputs.contains(deviceInput), canAddInput(deviceInput) {
            addInput(deviceInput)
        }

        updateVideoOutputConnection()
    }

    func updateVideoOutputConnection() {
        if let videoOutputConnection = videoOutput.connection(with: .video) {
            if videoOutputConnection.isVideoMirroringSupported {
                videoOutputConnection.isVideoMirrored = shouldMirrorVideo
            }
        }
    }

    func updatePhotoOutputConnection() {
        if let photoOutputConnection = photoOutput.connection(with: .video) {
            #if os(iOS)
            photoOutputConnection.updateVideoRotationAngle(90)
            #endif
        }
    }

    var shouldMirrorVideo: Bool {
        #if os(iOS)
        captureDevice?.position == .front
        #else
        true
        #endif
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }

        #if os(iOS)
        connection.updateVideoRotationAngle(90)
        #endif

        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = shouldMirrorVideo
        }

        addToPreviewStream?(CIImage(cvPixelBuffer: pixelBuffer))
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraSession: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            photoContinuations.forEach { $0.resume(throwing: error) }
            photoContinuations.removeAll()
        } else {
            addToPhotoStream?(photo)

            photoContinuations.forEach { $0.resume(returning: photo) }
            photoContinuations.removeAll()
        }
    }
}

// MARK: - Helpers

public extension AVCapturePhoto {
    /// Helper for getting `Image` from `AVCapturePhoto`
    func toImage() throws -> Image {
        guard let imageData = fileDataRepresentation() else {
            throw CameraError.invalidImage
        }
        return Image(imageData: imageData)
    }
}

extension AVCaptureConnection {
    func updateVideoRotationAngle(_ angle: CGFloat) {
        if videoRotationAngle != angle, isVideoRotationAngleSupported(angle) {
            videoRotationAngle = angle
        }
    }
}

#endif
