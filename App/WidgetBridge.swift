import Foundation
import WebKit
import WidgetKit

@MainActor
final class WidgetBridge: NSObject, WKScriptMessageHandler {
    weak var browser: BrowserSession?
    private let store: WidgetSnapshotStore
    private var stopped = false
    init(browser: BrowserSession, store: WidgetSnapshotStore = .shared) {
        self.browser = browser; self.store = store
        super.init()
        let old = store.read()
        if old.profileID != browser.profile.id { publish(WidgetSnapshot(profileID: browser.profile.id, state: .syncing)) }
    }
    func stop() { stopped = true }
    func refresh() {
        guard !stopped, let browser, let url = browser.webView.url,
              URLPolicy.sameOrigin(url, browser.profile.origin) else { return }
        browser.webView.evaluateJavaScript("window.RaftWidgetSync?.();true", completionHandler: nil)
    }
    private func publish(_ snapshot: WidgetSnapshot) {
        if store.write(snapshot) { WidgetCenter.shared.reloadTimelines(ofKind: "RaftStatusWidget") }
    }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !stopped, let browser, message.frameInfo.isMainFrame,
              let source = message.frameInfo.request.url, URLPolicy.sameOrigin(source, browser.profile.origin),
              let current = browser.webView.url, URLPolicy.sameOrigin(current, browser.profile.origin),
              var body = message.body as? [String: Any] else { return }
        body["profileID"] = browser.profile.id.uuidString
        body["updatedAt"] = Date().timeIntervalSince1970 * 1000
        guard let data = try? JSONSerialization.data(withJSONObject: body), data.count <= 16_384,
              var snapshot = try? WidgetSnapshot.decode(data) else { return }
        let old = store.read()
        if snapshot.state == .unavailable, old.profileID == snapshot.profileID, old.serverSlug == snapshot.serverSlug {
            snapshot = old; snapshot.state = .unavailable
        }
        publish(snapshot)
    }
    static func clearUnconfigured() {
        if WidgetSnapshotStore.shared.write(.empty) { WidgetCenter.shared.reloadTimelines(ofKind: "RaftStatusWidget") }
    }
    static let script = #"""
    if (location.origin === new URL(raftWidgetOrigin).origin) {
      let busy = false;
      const slugNow = () => {
        const match = location.pathname.match(/^\/s\/([^/]+)/);
        return match ? decodeURIComponent(match[1]) : localStorage.getItem('slock_last_server_slug');
      };
      const send = value => window.webkit.messageHandlers.raftWidgetSnapshot.postMessage({version:1, partial:false, tasks:[], ...value});
      const sync = async () => {
        if (busy || document.hidden) return;
        busy = true;
        const token = localStorage.getItem('slock_access_token');
        const slug = slugNow();
        const stillCurrent = () => token === localStorage.getItem('slock_access_token') && slug === slugNow();
        let server;
        try {
          if (!token) { send({state:'loggedOut'}); return; }
          const deadline = Date.now() + 12000;
          const get = async (path, serverID) => {
            const remaining = deadline - Date.now();
            if (remaining <= 0) throw new Error('timeout');
            const response = await fetch('/api' + path, {cache:'no-store', credentials:'same-origin',
              headers: {Authorization:'Bearer ' + token, ...(serverID ? {'X-Server-Id':serverID} : {})},
              signal:AbortSignal.timeout(remaining)});
            if (!response.ok) throw new Error('unavailable');
            return response.json();
          };
          const servers = await get('/servers');
          if (!Array.isArray(servers)) throw new Error('unsupported');
          server = servers.find(item => item.slug === slug) || (!slug && servers.length === 1 ? servers[0] : null);
          if (!server) { if (stillCurrent()) send({state:'selectServer'}); return; }
          const loadTasks = async () => {
            let tasks = [], cursor = null;
            const seen = new Set();
            for (let page = 0; page < 25; page++) {
              const result = await get('/tasks/server?detail=summary&limit=100' + (cursor ? '&cursor=' + encodeURIComponent(cursor) : ''), server.id);
              if (!Array.isArray(result.tasks)) throw new Error('unsupported');
              tasks.push(...result.tasks);
              cursor = result.next_cursor;
              if (!cursor) return {tasks, partial:false};
              if (typeof cursor !== 'string' || seen.has(cursor)) throw new Error('bad cursor');
              seen.add(cursor);
            }
            return {tasks, partial:true};
          };
          const [taskPage, summary] = await Promise.all([loadTasks(), get('/servers/unread-summary')]);
          if (!stillCurrent()) return;
          if (!Array.isArray(summary)) throw new Error('unsupported');
          const unread = summary.find(item => item.serverId === server.id);
          const tasks = taskPage.tasks;
          const allowed = ['todo','in_progress','in_review','done','closed'];
          if (tasks.some(task => !allowed.includes(task.status))) throw new Error('unsupported');
          const count = key => tasks.filter(task => task.status === key).length;
          const number = value => Number.isInteger(value) && value >= 0 && value <= 1000000 ? value : null;
          const title = value => Array.from(String(value || '')).slice(0,120).join('');
          send({state:'ready', serverName:title(server.name), serverSlug:server.slug,
            todo:count('todo'), inProgress:count('in_progress'), inReview:count('in_review'),
            unreadMessages:number(unread?.unreadCount), unreadActivity:number(unread?.activityUnreadCount), partial:taskPage.partial,
            tasks:tasks.filter(task => ['todo','in_progress','in_review'].includes(task.status))
              .sort((a,b) => (Date.parse(b.updatedAt)||0)-(Date.parse(a.updatedAt)||0)).slice(0,3)
              .map(task => ({number:task.taskNumber, title:title(task.title), status:task.status}))});
        } catch {
          if (stillCurrent()) send({state:'unavailable', ...(server ? {serverSlug:server.slug, serverName:String(server.name).slice(0,120)} : {})});
        } finally { busy = false; }
      };
      window.RaftWidgetSync = sync;
      window.addEventListener('pageshow', sync);
      window.addEventListener('focus', sync);
      document.addEventListener('visibilitychange', () => { if (!document.hidden) sync(); });
      const identity = () => {
        const token = localStorage.getItem('slock_access_token');
        if (!token) return 'logged-out';
        let subject = 'session';
        try { subject = JSON.parse(atob(token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).sub || subject; } catch {}
        return subject + ':' + (slugNow() || '');
      };
      let lastIdentity = identity();
      setInterval(() => {
        const current = identity();
        if (current !== lastIdentity) {
          lastIdentity = current;
          send({state:current === 'logged-out' ? 'loggedOut' : 'syncing'});
          sync();
        }
      }, 1000);
      setInterval(sync, 30000);
      sync();
    }
    """#
}
