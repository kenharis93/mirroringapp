import UIKit
import AVFoundation
import ReplayKit

// Configure these to your identifiers
private let appGroupId = "group.com.yourcompany.mirroringapp"
private let broadcastExtensionBundleId = "com.yourcompany.mirroringapp.BroadcastUploadExtension"

struct MirrorConfig: Codable {
    let h: String // host
    let p: Int    // port
    let sid: String
}

final class MainViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupCamera()
        setupUI()
    }

    private func setupUI() {
        statusLabel.text = "Scan Mac QR → Then Start Broadcast"
        statusLabel.numberOfLines = 2
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        picker.preferredExtension = broadcastExtensionBundleId
        picker.showsMicrophoneButton = false
        picker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: picker.topAnchor, constant: -12),
            picker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            picker.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            picker.widthAnchor.constraint(equalToConstant: 60),
            picker.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) { session.addOutput(output) }
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        session.startRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let raw = obj.stringValue,
              let data = raw.data(using: .utf8) else { return }
        do {
            let cfg = try JSONDecoder().decode(MirrorConfig.self, from: data)
            saveConfig(cfg)
            statusLabel.text = "Paired with \(cfg.h):\(cfg.p)\nTap the broadcast button below"
        } catch {
            statusLabel.text = "Invalid QR payload"
        }
    }

    private func saveConfig(_ cfg: MirrorConfig) {
        guard let ud = UserDefaults(suiteName: appGroupId),
              let data = try? JSONEncoder().encode(cfg) else { return }
        ud.set(data, forKey: "MirrorConfig")
    }
}

