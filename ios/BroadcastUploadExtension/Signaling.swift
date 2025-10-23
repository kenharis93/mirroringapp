import Foundation

enum SignalMessage: Codable {
    case hello(role: String, sid: String)
    case offer(sid: String, sdp: SDP)
    case answer(sid: String, sdp: SDP)
    case ice(sid: String, candidate: Ice?)

    struct SDP: Codable { let type: String; let sdp: String }
    struct Ice: Codable {
        let candidate: String
        let sdpMid: String?
        let sdpMLineIndex: Int32?
    }

    private enum CodingKeys: String, CodingKey { case type, role, sid, sdp, candidate }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "hello":
            self = .hello(role: try c.decode(String.self, forKey: .role), sid: try c.decode(String.self, forKey: .sid))
        case "offer":
            self = .offer(sid: try c.decode(String.self, forKey: .sid), sdp: try c.decode(SDP.self, forKey: .sdp))
        case "answer":
            self = .answer(sid: try c.decode(String.self, forKey: .sid), sdp: try c.decode(SDP.self, forKey: .sdp))
        case "ice":
            self = .ice(sid: try c.decode(String.self, forKey: .sid), candidate: try? c.decode(Ice.self, forKey: .candidate))
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "unknown type"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .hello(role, sid):
            try c.encode("hello", forKey: .type)
            try c.encode(role, forKey: .role)
            try c.encode(sid, forKey: .sid)
        case let .offer(sid, sdp):
            try c.encode("offer", forKey: .type)
            try c.encode(sid, forKey: .sid)
            try c.encode(sdp, forKey: .sdp)
        case let .answer(sid, sdp):
            try c.encode("answer", forKey: .type)
            try c.encode(sid, forKey: .sid)
            try c.encode(sdp, forKey: .sdp)
        case let .ice(sid, cand):
            try c.encode("ice", forKey: .type)
            try c.encode(sid, forKey: .sid)
            try c.encodeIfPresent(cand, forKey: .candidate)
        }
    }
}

final class WebSocketSignaling: NSObject {
    private var task: URLSessionWebSocketTask?
    private let url: URL
    private let sid: String

    var onAnswer: ((SignalMessage.SDP) -> Void)?
    var onIce: ((SignalMessage.Ice) -> Void)?
    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?

    init(host: String, port: Int, sid: String) {
        self.url = URL(string: "ws://\(host):\(port)")!
        self.sid = sid
        super.init()
    }

    func connectAsSender() {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = false
        let session = URLSession(configuration: cfg)
        task = session.webSocketTask(with: url)
        task?.resume()
        receiveLoop()
        send(.hello(role: "sender", sid: sid))
        onOpen?()
    }

    func close() { task?.cancel(with: .goingAway, reason: nil); onClose?() }

    func send(_ msg: SignalMessage) {
        guard let task = task else { return }
        let enc = JSONEncoder()
        guard let data = try? enc.encode(msg), let txt = String(data: data, encoding: .utf8) else { return }
        task.send(.string(txt)) { _ in }
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let m):
                if case let .string(txt) = m, let data = txt.data(using: .utf8) {
                    self.handle(data: data)
                }
            case .failure:
                break
            }
            self.receiveLoop()
        }
    }

    private func handle(data: Data) {
        let dec = JSONDecoder()
        if let msg = try? dec.decode(SignalMessage.self, from: data) {
            switch msg {
            case .answer(_, let sdp): onAnswer?(sdp)
            case .ice(_, let cand): if let c = cand { onIce?(c) }
            default: break
            }
        }
    }
}

