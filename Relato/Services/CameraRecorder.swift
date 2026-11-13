@preconcurrency import AVFoundation
import Foundation
import SwiftUI
import UIKit

/// Owns the capture session. Every AVFoundation call happens on a private serial queue,
/// so the main thread never blocks on camera configuration, start or stop.
final class CameraSession: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    enum CameraError: LocalizedError {
        case unavailable
        case configurationFailed

        var errorDescription: String? {
            switch self {
            case .unavailable: "La cámara frontal no está disponible."
            case .configurationFailed: "No se pudo preparar la cámara."
            }
        }
    }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.relato.camera", qos: .userInitiated)
    private let movieOutput = AVCaptureMovieFileOutput()
    private var isConfigured = false

    /// Called on the camera queue whenever a recording file is finalized (requested stop, interruption or error).
    /// Set once, before the first recording.
    var onFinish: (@Sendable (URL, Bool) -> Void)?

    static var hasFrontCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    func configure(includeAudio: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.configureOnQueue(includeAudio: includeAudio)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func configureOnQueue(includeAudio: Bool) throws {
        guard !isConfigured else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = session.canSetSessionPreset(.hd1920x1080) ? .hd1920x1080 : .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.unavailable
        }
        let videoInput = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(videoInput) else { throw CameraError.configurationFailed }
        session.addInput(videoInput)

        if includeAudio,
           let microphone = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: microphone),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        guard session.canAddOutput(movieOutput) else { throw CameraError.configurationFailed }
        session.addOutput(movieOutput)

        if let connection = movieOutput.connection(with: .video) {
            // Vertical video: the app is portrait-only.
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .auto }
        }
        isConfigured = true
    }

    func startRunning() {
        queue.async {
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopRunning() {
        queue.async {
            if self.movieOutput.isRecording { self.movieOutput.stopRecording() }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func startRecording(to url: URL) {
        queue.async {
            guard self.isConfigured, !self.movieOutput.isRecording else { return }
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        queue.async {
            if self.movieOutput.isRecording { self.movieOutput.stopRecording() }
        }
    }

    // MARK: AVCaptureFileOutputRecordingDelegate

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        var success = error == nil
        if let error {
            // An interruption can still produce a valid, playable file.
            success = (error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
        }
        onFinish?(outputFileURL, success)
    }
}

struct RecordedClip: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let duration: Double
}

@MainActor
@Observable
final class RecorderModel {
    enum Phase: Equatable {
        case idle
        case preparing
        case ready
        case recording
        case finishing
        case unavailable(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var recordingStartedAt: Date?
    private(set) var hasAudio = false
    private(set) var lastError: String?
    /// Set when a take file is finalized; the view consumes it and sets it back to nil.
    var finishedClip: RecordedClip?

    @ObservationIgnored let camera = CameraSession()

    init() {
        camera.onFinish = { [weak self] url, success in
            Task { @MainActor in await self?.handleFinish(url: url, success: success) }
        }
    }

    var isRecording: Bool { phase == .recording }

    func prepare() async {
        guard phase == .idle else { return }
        phase = .preparing
        guard CameraSession.hasFrontCamera else {
            phase = .unavailable("Este dispositivo no tiene cámara frontal disponible. Puedes ensayar el guion igualmente.")
            return
        }
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            phase = .unavailable("Relato necesita la cámara para grabar. Actívala en Ajustes › Relato › Cámara.")
            return
        }
        let audioAllowed = await AVCaptureDevice.requestAccess(for: .audio)
        do {
            try await camera.configure(includeAudio: audioAllowed)
            hasAudio = audioAllowed
            camera.startRunning()
            phase = .ready
        } catch {
            phase = .unavailable(error.localizedDescription)
        }
    }

    func startRecording() {
        guard phase == .ready else { return }
        do {
            let url = try TakeStorage.makeRecordingURL()
            lastError = nil
            camera.startRecording(to: url)
            recordingStartedAt = .now
            phase = .recording
        } catch {
            lastError = "No hay espacio para guardar la toma."
        }
    }

    func stopRecording() {
        guard phase == .recording else { return }
        phase = .finishing
        camera.stopRecording()
    }

    func shutdown() {
        camera.stopRunning()
        if phase == .ready { phase = .idle }
    }

    func resume() {
        guard phase == .idle || phase == .ready else { return }
        if phase == .idle {
            Task { await prepare() }
        } else {
            camera.startRunning()
        }
    }

    private func handleFinish(url: URL, success: Bool) async {
        let fallback = recordingStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0
        recordingStartedAt = nil
        let exists = FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
        let duration = exists ? (await TakeStorage.duration(of: url) ?? fallback) : 0

        if success, exists, duration >= 0.5 {
            finishedClip = RecordedClip(url: url, duration: duration)
        } else {
            try? FileManager.default.removeItem(at: url)
            lastError = duration < 0.5 && success ? "La toma fue demasiado corta." : "La grabación se interrumpió y no se pudo guardar."
        }
        if phase == .recording || phase == .finishing { phase = .ready }
    }
}

/// Live front-camera preview.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // layerClass guarantees the type.
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }
}
