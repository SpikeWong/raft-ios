import SwiftUI

@MainActor
final class ShellModel: ObservableObject {
    @Published var browser: BrowserSession?
    @Published var editingConnection = false
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
        if let active = store.active { attach(active) } else { WidgetBridge.clearUnconfigured() }
    }

    func connect(_ address: String) throws {
        let profile = try store.select(address)
        if browser?.profile.id != profile.id {
            browser?.stop()
            attach(profile)
        }
        editingConnection = false
    }

    func openWidget(_ url: URL) {
        guard let browser, let path = WidgetSnapshot.route(for: url, activeProfile: browser.profile.id) else { return }
        editingConnection = false
        browser.openWidgetRoute(path)
    }

    private func attach(_ profile: ConnectionProfile) {
        browser = BrowserSession(profile: profile) { [weak store] url in store?.remember(url, for: profile) }
    }

}
