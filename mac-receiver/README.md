Mirror Receiver (macOS / Electron)

What this does
- Starts a local WebSocket signaling server on a random port
- Shows a QR code with host/port/session id for pairing
- Receives WebRTC video from the iOS Broadcast Upload Extension and renders it in a window

Develop
1) Install dependencies
   cd mac-receiver
   npm install

2) Run
   npm start

3) Package (.app/.dmg)
   npm run dist

Notes
- The QR payload is a small JSON object: {"h":"<host>","p":<port>,"sid":"<session>"}
- The iOS side connects to ws://<host>:<port>, sends hello+sid, then WebRTC offer/ICE.
- This window can be shared in Zoom/Meet using window-only sharing; toggle Always-on-top if helpful.
