import XCTest
#if canImport(RaftWidgetData)
@testable import RaftWidgetData
#else
@testable import RaftPersonal
#endif

final class WidgetSnapshotTests: XCTestCase {
    private let profile = UUID(uuidString: "6CB98BDA-95C2-41D8-AE35-320F9D83B8DC")!
    private func snapshot() -> WidgetSnapshot {
        WidgetSnapshot(profileID: profile, state: .ready, serverName: "Example", serverSlug: "example", todo: 2, inProgress: 3, inReview: 1, unreadMessages: 7, unreadActivity: nil, tasks: [WidgetTask(number: 4, title: "Review interface", status: "in_review")], updatedAt: Date())
    }
    func testSnapshotRoundTripUnknownUnreadAndStaleness() throws {
        let original = snapshot()
        let decoded = try WidgetSnapshot.decode(original.encoded())
        XCTAssertEqual(decoded.todo, 2)
        XCTAssertNil(decoded.unreadActivity, "Unknown must remain different from zero")
        XCTAssertFalse(decoded.isStale(at: original.updatedAt!))
        XCTAssertTrue(decoded.isStale(at: original.updatedAt!.addingTimeInterval(901)))
        XCTAssertEqual(decoded.tasks, original.tasks)
    }
    func testRejectsInvalidCountsStatusAndTitle() throws {
        var value = snapshot(); value.todo = -1
        XCTAssertThrowsError(try WidgetSnapshot.decode(value.encoded()))
        value = snapshot(); value.tasks = [WidgetTask(number: 4, title: "bad", status: "unknown")]
        XCTAssertThrowsError(try WidgetSnapshot.decode(value.encoded()))
        value = snapshot(); value.tasks = [WidgetTask(number: 4, title: String(repeating: "a", count: 121), status: "todo")]
        XCTAssertThrowsError(try WidgetSnapshot.decode(value.encoded()))
        value = snapshot(); value.serverSlug = "../external"
        XCTAssertThrowsError(try WidgetSnapshot.decode(value.encoded()))
    }
    func testDeepLinkRequiresActiveProfileAndFixedRoutes() throws {
        let url = try XCTUnwrap(snapshot().link(section: "activity"))
        XCTAssertEqual(WidgetSnapshot.route(for: url, activeProfile: profile), "/s/example/activity")
        XCTAssertNil(WidgetSnapshot.route(for: url, activeProfile: UUID()))
        XCTAssertNil(snapshot().link(section: "logout"))
        for suffix in ["&url=https://outside.example", "&section=tasks", "&token=unused"] {
            XCTAssertNil(WidgetSnapshot.route(for: URL(string: url.absoluteString + suffix)!, activeProfile: profile))
        }
        XCTAssertNil(WidgetSnapshot.route(for: URL(string: url.absoluteString.replacingOccurrences(of: "server=example", with: "server=..%2Fother"))!, activeProfile: profile))
    }
    func testSharedFileReplacesOldDeploymentAndDropsUnknownFields() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetSnapshotStore(directory: directory)
        XCTAssertTrue(store.write(snapshot()))
        XCTAssertEqual(store.read().profileID, profile)
        XCTAssertTrue(store.write(WidgetSnapshot(profileID: UUID(), state: .syncing)))
        XCTAssertNil(store.read().todo)
        XCTAssertTrue(store.write(WidgetSnapshot(state: .loggedOut)))
        XCTAssertNil(store.read().profileID)
        var body = try XCTUnwrap(JSONSerialization.jsonObject(with: snapshot().encoded()) as? [String:Any])
        body["accessToken"] = "fixture-only"
        let decoded = try WidgetSnapshot.decode(JSONSerialization.data(withJSONObject: body))
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: decoded.encoded()) as? [String:Any])
        XCTAssertNil(saved["accessToken"], "Only declared presentation fields are stored")
    }
}
