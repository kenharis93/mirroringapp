Local iPhone-to-Mac Mirroring (ReplayKit + WebRTC)

Overview
- macOS receiver: Electron app showing a window you can share on calls.
- iOS sender: App with QR scanner + Broadcast Upload Extension using ReplayKit.

Quick Start
- Receiver (Mac):
  - cd mac-receiver
  - npm install
  - npm start
  - Optionally: npm run dist to build .app/.dmg

- iOS App + Extension:
  - cd ios
  - pod install
  - open MirroringApp.xcworkspace
  - In Xcode, set your Team and ensure bundle IDs are unique for both targets.
  - Update App Group to match your Team (default: group.com.yourcompany.mirroringapp) in both entitlements.
  - Build & run the app on a physical device.
  - In the app, scan the QR displayed by the Mac receiver.
  - Tap the broadcast button, select the BroadcastUploadExtension, and mirroring should begin.

Notes
- Both devices must be on the same local network.
- ReplayKit blocks DRM-protected content.
- Video-only MVP; audio capture can be added later.

