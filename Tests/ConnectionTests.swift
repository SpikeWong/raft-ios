import XCTest
@testable import RaftPersonal

final class ConnectionTests: XCTestCase {
    func testAddressValidationAndNormalization() throws {
        XCTAssertEqual(try URLPolicy.normalize("  RAFT.example.com/  ").absoluteString, "https://raft.example.com")
        XCTAssertEqual(try URLPolicy.normalize("raft.example.com:8443").port, 8443)
        XCTAssertEqual(try URLPolicy.normalize("https://raft.example.com:443/").absoluteString, "https://raft.example.com")
        XCTAssertNoThrow(try URLPolicy.normalize("https://[2001:db8::1]:8443"))
        XCTAssertNoThrow(try URLPolicy.normalize("http://[::1]:3000"))
        XCTAssertNoThrow(try URLPolicy.normalize("http://192.168.1.3:3000"))
        XCTAssertNoThrow(try URLPolicy.normalize("http://raft.local:3000"))
        for value in ["", "javascript:alert(1)", "file:///tmp/a", "https://user:pass@raft.example.com",
                      "http://example.com", "https://raft.example.com/path", "https://raft.example.com?token=secret",
                      "https://raft.example.com#token", "https://raft.example.com:99999", "https://"] {
            XCTAssertThrowsError(try URLPolicy.normalize(value), value)
        }
    }

    func testProfilesPersistAndStayIsolated() throws {
        let suite = "RaftPersonal.Tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ConnectionStore(defaults: defaults)
        let first = try store.select("https://one.example.com")
        store.remember(URL(string: "https://one.example.com/channel/123")!, for: first)
        let second = try store.select("https://two.example.com")
        XCTAssertNotEqual(first.id, second.id)
        let reloaded = ConnectionStore(defaults: defaults)
        XCTAssertEqual(reloaded.active?.id, second.id)
        let selected = try reloaded.select("https://ONE.example.com:443/")
        XCTAssertEqual(first.id, selected.id)
        XCTAssertEqual(selected.lastPath, "/channel/123")
        reloaded.forgetPath(for: second)
        XCTAssertEqual(try reloaded.select("https://one.example.com").lastPath, "/channel/123")
    }

    func testSensitiveOrExternalPathsAreNotRestored() throws {
        let base = try URLPolicy.normalize("https://one.example.com")
        XCTAssertEqual(URLPolicy.restorablePath(URL(string: "https://one.example.com/tasks")!, base: base), "/tasks")
        for value in ["https://two.example.com/tasks", "https://one.example.com/auth/callback",
                      "https://one.example.com/?code=secret", "https://one.example.com/invite/secret",
                      "https://one.example.com/reset-password", "https://one.example.com/channel/123#secret"] {
            XCTAssertNil(URLPolicy.restorablePath(URL(string: value)!, base: base), value)
        }
    }
}
