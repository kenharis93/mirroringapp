import Foundation
import WebRTC

final class PeerConnectionManager: NSObject, RTCPeerConnectionDelegate {
    private(set) var pc: RTCPeerConnection!
    private var factory: RTCPeerConnectionFactory!
    private var videoSource: RTCVideoSource!
    private var capturer: ReplayKitCapturer!
    private let signaling: WebSocketSignaling
    private let sid: String

    init(host: String, port: Int, sid: String) {
        self.signaling = WebSocketSignaling(host: host, port: port, sid: sid)
        self.sid = sid
        super.init()
        setupFactory()
        setupPC()
    }

    private func setupFactory() {
        RTCInitializeSSL()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
    }

    private func setupPC() {
        let config = RTCConfiguration()
        config.iceServers = []
        config.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        pc = factory.peerConnection(with: config, constraints: constraints, delegate: self)

        videoSource = factory.videoSource(forScreenCast: true)
        let track = factory.videoTrack(with: videoSource, trackId: "v0")
        let transceiverInit = RTCRtpTransceiverInit()
        transceiverInit.direction = .sendOnly
        _ = pc.addTransceiver(with: track, init: transceiverInit)

        capturer = ReplayKitCapturer(delegate: videoSource)

        signaling.onAnswer = { [weak self] sdp in
            let rsd = RTCSessionDescription(type: .answer, sdp: sdp.sdp)
            self?.pc.setRemoteDescription(rsd, completionHandler: { _ in })
        }
        signaling.onIce = { [weak self] cand in
            let c = RTCIceCandidate(sdp: cand.candidate, sdpMLineIndex: cand.sdpMLineIndex ?? 0, sdpMid: cand.sdpMid)
            self?.pc.add(c)
        }
    }

    func start() {
        signaling.connectAsSender()
        // Create offer once signaling is up
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveVideo": "false"], optionalConstraints: nil)
        pc.offer(for: constraints) { [weak self] sdp, _ in
            guard let self = self, let sdp = sdp else { return }
            self.pc.setLocalDescription(sdp) { _ in }
            self.signaling.send(.offer(sid: self.sid, sdp: .init(type: sdp.type.rawValue, sdp: sdp.sdp)))
        }
    }

    func ingest(sampleBuffer: CMSampleBuffer, type: RPSampleBufferType) {
        if type == .video { capturer.process(sampleBuffer: sampleBuffer) }
    }

    func stop() {
        signaling.close()
        pc.close()
        RTCCleanupSSL()
    }

    // MARK: - RTCPeerConnectionDelegate (minimal)
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        signaling.send(.ice(sid: sid, candidate: .init(candidate: candidate.sdp, sdpMid: candidate.sdpMid, sdpMLineIndex: candidate.sdpMLineIndex)))
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

