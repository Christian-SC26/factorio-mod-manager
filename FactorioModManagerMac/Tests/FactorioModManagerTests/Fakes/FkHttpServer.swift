import Foundation
import Network

/// Local HTTP server on an ephemeral port that answers every request with the same response.
final class FkHttpServer: @unchecked Sendable {
    struct Failed: Error {}

    private let listener: NWListener
    let url: URL

    init(status: Int, body: Data) async throws {
        let listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { _, _, _, _ in
                let head = "HTTP/1.1 \(status) Fake\r\nContent-Type: application/zip\r\n"
                    + "Content-Length: \(body.count)\r\nConnection: close\r\n\r\n"
                connection.send(
                    content: Data(head.utf8) + body,
                    completion: .contentProcessed { _ in connection.cancel() }
                )
            }
        }
        let port: UInt16 = await withCheckedContinuation { continuation in
            let once = Once()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    once.run { continuation.resume(returning: listener.port?.rawValue ?? 0) }
                case .failed, .cancelled:
                    once.run { continuation.resume(returning: 0) }
                default:
                    break
                }
            }
            listener.start(queue: .global())
        }
        guard port != 0 else {
            listener.cancel()
            throw Failed()
        }
        self.listener = listener
        self.url = URL(string: "http://127.0.0.1:\(port)/download.zip")!
    }

    func close() {
        listener.cancel()
    }
}

private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        action()
    }
}
