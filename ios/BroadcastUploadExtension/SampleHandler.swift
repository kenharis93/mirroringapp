import ReplayKit
import WebRTC

// Must match the app group used by the host app
private let appGroupId = "group.com.yourcompany.mirroringapp"

struct MirrorConfig: Codable { let h: String; let p: Int; let sid: String }

class SampleHandler: RPBroadcastSampleHandler {
    private var pcm: PeerConnectionManager?

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        guard let ud = UserDefaults(suiteName: appGroupId),
              let data = ud.data(forKey: "MirrorConfig"),
              let cfg = try? JSONDecoder().decode(MirrorConfig.self, from: data) else {
            finishBroadcastWithError(NSError(domain: "Mirror", code: -1, userInfo: [NSLocalizedDescriptionKey: "No pairing config found. Open the app and scan the QR code first."]))
            return
        }
        pcm = PeerConnectionManager(host: cfg.h, port: cfg.p, sid: cfg.sid)
        pcm?.start()
    }

    override func broadcastPaused() { /* Optional: handle pause */ }
    override func broadcastResumed() { /* Optional: handle resume */ }

    override func broadcastFinished() {
        pcm?.stop()
        pcm = nil
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        pcm?.ingest(sampleBuffer: sampleBuffer, type: sampleBufferType)
    }
}

