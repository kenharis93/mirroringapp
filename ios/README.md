iOS Sender App + Broadcast Upload Extension (ReplayKit + WebRTC)

Overview
- App lets you scan the QR from the Mac receiver and stores pairing params (host, port, sid).
- A Broadcast Upload Extension (started via Control Center) captures the screen via ReplayKit and streams it over WebRTC to the Mac.

Project Setup (Xcode)
1) Create a new iOS App project (Swift, UIKit or SwiftUI).
2) Or open the pre-made project at ios/MirroringApp.xcodeproj (recommended).
3) Add an App Group capability to both the App and Extension, e.g. group.com.yourcompany.mirroringapp (already present in entitlements, update to yours).
4) Install pods and open the workspace:
   - cd ios
   - pod install
   - open MirroringApp.xcworkspace
5) Update bundle identifiers to your Team in Xcode for both targets if needed.
6) Implemented SampleHandler already does:
   - Read pairing params from the App Group
   - Connect a URLSessionWebSocketTask to ws://<host>:<port>
   - Initialize RTCPeerConnection, add a screen-cast video track
   - Create and send an SDP offer; exchange ICE; feed ReplayKit frames to WebRTC

Minimum Files in this folder (reference)
- MirroringApp/MainViewController.swift: QR scanning + Broadcast picker button.
- BroadcastUploadExtension/SampleHandler.swift: ReplayKit entry point.
- BroadcastUploadExtension/ReplayKitCapturer.swift: Pipes CMSampleBuffer video to WebRTC.
- BroadcastUploadExtension/Signaling.swift: Lightweight WebSocket signaling client.
- BroadcastUploadExtension/PeerConnection.swift: WebRTC peer connection management.
 - MirroringApp.xcodeproj: Preconfigured app + extension targets.

Build/Run
- App: run on device, scan QR from the Mac receiver, then tap the Broadcast Picker and choose your extension.
- Extension: start from iOS Control Center screen recording button; select your extension to start mirroring.

Notes
- DRM-protected apps will block ReplayKit capture.
- For local LAN use, no STUN/TURN is needed. Ensure phone and Mac are on the same network.
- If you change the App Group ID, update the code constants accordingly.
 - If local WebSocket fails due to ATS, ATS is already relaxed in both Info.plists.
