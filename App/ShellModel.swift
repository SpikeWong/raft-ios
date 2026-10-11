import SwiftUI

@MainActor
final class ShellModel: ObservableObject {
    @Published var browser: BrowserSession?
    @Published var editingConnection = false
    @Published var clearingData = false
    let store: ConnectionStore

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let defaults = UserDefaults(suiteName: "RaftPersonal.UITests")!
            if !ProcessInfo.processInfo.arguments.contains("--keep-test-data") {
                defaults.removePersistentDomain(forName: "RaftPersonal.UITests")
            }
            store = ConnectionStore(defaults: defaults)
        } else { store = ConnectionStore() }
        #else
        store = ConnectionStore()
        #endif
        if let active = store.active { attach(active) }
    }

    func connect(_ address: String) throws {
        let profile = try store.select(address)
        if browser?.profile.id != profile.id {
            browser?.stop()
            attach(profile)
        }
        editingConnection = false
    }

    private func attach(_ profile: ConnectionProfile) {
        browser = BrowserSession(profile: profile) { [weak store] url in store?.remember(url, for: profile) }
    }

    func clearCurrentData() async {
        guard let current = browser else { return }
        clearingData = true
        // Remove the old WebView from the hierarchy before clearing its store.
        browser = nil
        await current.clearData()
        store.forgetPath(for: current.profile)
        if let active = store.active { attach(active) }
        clearingData = false
    }
}
