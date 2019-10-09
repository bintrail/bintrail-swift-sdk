internal struct SessionCredentials {
    let token: String
    let expirationDate: Date
    let sessionIdentifier: String
}

extension SessionCredentials: Codable {
    private enum CodingKeys: String, CodingKey {
        case token = "bearerToken"
        case expirationDate = "expiresAt"
        case sessionIdentifier = "sessionId"
    }
}

public final class Session {

    internal var credentials: SessionCredentials?

    @Synchronized private(set) var events: [SessionEvent]

    internal func dequeueEvents(count: Int) {
        bt_debug("Dequeueing \(count) event(s) from session.")
        events.removeFirst(count)
    }

    internal func enqueueEvent(_ event: SessionEvent) {
        events.append(event)
    }

    internal init() {
        events = []
    }
}

extension Session: Equatable {
    public static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs === rhs
    }
}

extension Session: Codable {}
