@preconcurrency import AVFoundation
import DrumAI
import SwiftUI
import UIKit

/// Front-camera preview and video-only recording for the posture self-check.
@MainActor
final class PracticeRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var lastVideo: URL?
    let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private var startedAt = Date()

    static var videosDir: URL {
        let d = URL.documentsDirectory.appending(path: "Videos")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func configure() async -> Bool {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
        guard session.inputs.isEmpty else { return true }
        session.beginConfiguration()
        session.sessionPreset = .high
        if let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: cam), session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        let s = session
        Task.detached { s.startRunning() }
        return true
    }

    func stop() {
        if output.isRecording { output.stopRecording() }
        let s = session
        Task.detached { s.stopRunning() }
    }

    func toggleRecording() {
        if output.isRecording { output.stopRecording(); return }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        startedAt = Date()
        output.startRecording(to: Self.videosDir.appending(path: "\(f.string(from: Date())).mov"), recordingDelegate: self)
        isRecording = true
    }

    /// JPEG frames spread over the clip (skipping the first 4 s count-in).
    static func frames(from url: URL, count: Int = 4) async -> [Data] {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return [] }
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 1024, height: 1024)
        var out: [Data] = []
        for t in PostureCheck.pickFrames(count: count, duration: duration.seconds, avoidFirst: min(4, duration.seconds / 4)) {
            if let cg = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)).image,
               let jpg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.7) { out.append(jpg) }
        }
        return out
    }

    /// Delete videos older than 30 days unless starred.
    static func cleanUp(starred: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(at: videosDir, includingPropertiesForKeys: [.creationDateKey])) ?? []
        for f in files where !starred.contains(f.lastPathComponent) {
            let created = (try? f.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            if Date().timeIntervalSince(created) > 30 * 86_400 { try? FileManager.default.removeItem(at: f) }
        }
    }
}

extension PracticeRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            self.isRecording = false
            self.lastVideo = url
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.layer.session = session
        v.layer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        override var layer: AVCaptureVideoPreviewLayer { super.layer as! AVCaptureVideoPreviewLayer }
    }
}
