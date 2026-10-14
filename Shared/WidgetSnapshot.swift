import Foundation

struct WidgetTask: Codable, Equatable, Identifiable {
    let number: Int
    let title: String
    let status: String
    var id: String { "\(number)-\(title)" }
}

struct WidgetSnapshot: Codable, Equatable {
    enum State: String, Codable { case notConfigured, syncing, loggedOut, selectServer, ready, unavailable }
    var version = 1
    var profileID: UUID?
    var state: State
    var serverName: String?
    var serverSlug: String?
    var todo: Int?
    var inProgress: Int?
    var inReview: Int?
    var unreadMessages: Int?
    var unreadActivity: Int?
    var partial = false
    var tasks: [WidgetTask] = []
    var updatedAt: Date?

    static let empty = WidgetSnapshot(state: .notConfigured)
    static func validSlug(_ slug: String) -> Bool {
        !slug.isEmpty && slug.count <= 80 && slug.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
    }
    static func decode(_ data: Data) throws -> WidgetSnapshot {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
        let value = try decoder.decode(Self.self, from: data)
        guard data.count <= 16_384, value.version == 1,
              value.serverSlug.map(validSlug) ?? true,
              value.serverName.map({ $0.count <= 120 }) ?? true,
              value.tasks.count <= 3,
              [value.todo, value.inProgress, value.inReview, value.unreadMessages, value.unreadActivity].allSatisfy({ $0.map { (0...1_000_000).contains($0) } ?? true }),
              value.tasks.allSatisfy({ $0.number > 0 && $0.title.count <= 120 && ["todo", "in_progress", "in_review", "done", "closed"].contains($0.status) }),
              value.state != .ready || (value.profileID != nil && value.serverSlug != nil && value.todo != nil && value.inProgress != nil && value.inReview != nil && value.updatedAt != nil)
        else { throw CocoaError(.coderInvalidValue) }
        return value
    }
    func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(self)
    }
    func isStale(at date: Date) -> Bool { updatedAt.map { date.timeIntervalSince($0) > 15 * 60 } ?? true }
    func link(section: String) -> URL? {
        guard let profileID, let serverSlug, Self.validSlug(serverSlug), ["tasks", "activity"].contains(section) else { return nil }
        var url = URLComponents(); url.scheme = "raftpersonal"; url.host = "widget"
        url.queryItems = [URLQueryItem(name: "profile", value: profileID.uuidString), URLQueryItem(name: "server", value: serverSlug), URLQueryItem(name: "section", value: section)]
        return url.url
    }
    static func route(for url: URL, activeProfile: UUID) -> String? {
        guard url.scheme == "raftpersonal", url.host == "widget", url.path.isEmpty,
              url.user == nil, url.password == nil, url.port == nil, url.fragment == nil,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems, items.count == 3,
              Set(items.map(\.name)) == ["profile", "server", "section"],
              let profile = items.first(where: { $0.name == "profile" })?.value,
              UUID(uuidString: profile) == activeProfile,
              let slug = items.first(where: { $0.name == "server" })?.value, validSlug(slug),
              let section = items.first(where: { $0.name == "section" })?.value, ["tasks", "activity"].contains(section)
        else { return nil }
        return "/s/\(slug)/\(section)"
    }
}

struct WidgetSnapshotStore {
    let directory: URL?
    static var shared: Self {
        let group = Bundle.main.object(forInfoDictionaryKey: "RaftWidgetAppGroupIdentifier") as? String
        return Self(directory: group.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) })
    }
    var file: URL? { directory?.appendingPathComponent("widget-snapshot.json") }
    func read() -> WidgetSnapshot {
        guard let file, let data = try? Data(contentsOf: file), let value = try? WidgetSnapshot.decode(data) else { return .empty }
        return value
    }
    @discardableResult func write(_ value: WidgetSnapshot) -> Bool {
        guard let file, let data = try? value.encoded(), (try? WidgetSnapshot.decode(data)) != nil else { return false }
        do {
            try data.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: file.path)
            #endif
            return true
        } catch { return false }
    }
}
