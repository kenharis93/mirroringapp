import Foundation
import ReplayKit
import WebRTC

final class ReplayKitCapturer: RTCVideoCapturer {
    func process(sampleBuffer: CMSampleBuffer) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let tsNs = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1_000_000_000
        let rtcBuf = RTCCVPixelBuffer(pixelBuffer: pb)
        let frame = RTCVideoFrame(buffer: rtcBuf, rotation: ._0, timeStampNs: Int64(tsNs))
        self.delegate?.capturer(self, didCapture: frame)
    }
}

