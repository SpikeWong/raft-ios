import Foundation

struct ConnectionProfile: Codable, Equatable, Identifiable {
    let id: UUID
    let origin: URL
    var lastPath: String?
}

final class ConnectionStore {
    private let defaults: UserDefaults
    private let key = "raft.connections.v1"
    private struct Snapshot: Codable {
        var profiles: [ConnectionProfile] = []
        var activeID: UUID?
    }
    private var snapshot: Snapshot

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        snapshot = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) } ?? Snapshot()
    }

    var active: ConnectionProfile? { snapshot.profiles.first { $0.id == snapshot.activeID } }

    @discardableResult
    func select(_ input: String) throws -> ConnectionProfile {
        let origin = try URLPolicy.normalize(input)
        let profile = snapshot.profiles.first { URLPolicy.sameOrigin($0.origin, origin) }
            ?? ConnectionProfile(id: UUID(), origin: origin)
        if !snapshot.profiles.contains(where: { $0.id == profile.id }) { snapshot.profiles.append(profile) }
        snapshot.activeID = profile.id
        persist()
        return profile
    }

    func remember(_ url: URL, for profile: ConnectionProfile) {
        guard let path = URLPolicy.restorablePath(url, base: profile.origin),
              let index = snapshot.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        snapshot.profiles[index].lastPath = path
        persist()
    }

    func forgetPath(for profile: ConnectionProfile) {
        guard let index = snapshot.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        snapshot.profiles[index].lastPath = nil
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}
