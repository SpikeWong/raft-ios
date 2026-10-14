import Combine
import UIKit
import WebKit

@MainActor
final class BrowserSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let profile: ConnectionProfile
    let webView: WKWebView
    @Published var isLoading = true
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    @Published var notice: String?
    let serverSettingsRequests = PassthroughSubject<Void, Never>()
    private var observations: [NSKeyValueObservation] = []
    private var widgetBridge: WidgetBridge?
    private var started = false
    private let onSafePath: (URL) -> Void

    init(profile: ConnectionProfile, onSafePath: @escaping (URL) -> Void) {
        self.profile = profile
        self.onSafePath = onSafePath
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: profile.id)
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.configuration.userContentController.add(WeakConnectionHandler(self), name: "raftConnection")
        let origin = String(data: try! JSONEncoder().encode(profile.origin.absoluteString), encoding: .utf8)!
        webView.configuration.userContentController.addUserScript(WKUserScript(
            source: "const raftConnectionOrigin = \(origin);\n" + Self.connectionSettingsScript,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView.configuration.userContentController.addUserScript(WKUserScript(
            source: "(() => { const raftComposerOrigin = \(origin);\n" + ComposerPreviewStyle.script + "\n})();",
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView.configuration.userContentController.addUserScript(WKUserScript(
            source: "(() => { const raftHomeOrigin = \(origin);\n" + HomeTouchPolicy.script + "\n})();",
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let bridge = WidgetBridge(browser: self)
        widgetBridge = bridge
        webView.configuration.userContentController.add(bridge, name: "raftWidgetSnapshot")
        webView.configuration.userContentController.addUserScript(WKUserScript(
            source: "(() => { const raftWidgetOrigin = \(origin);\n" + WidgetBridge.script + "\n})();",
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.keyboardDismissMode = .interactive
        // The page uses viewport-fit=cover and CSS safe-area padding. UIKit's
        // automatic scroll inset would subtract the home-indicator area again.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.backgroundColor = .systemBackground
        webView.isOpaque = false
        #if DEBUG
        webView.isInspectable = true
        #endif
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.progress = view.estimatedProgress }
            }
        ]
    }

    func start() {
        guard !started else { return }
        started = true
        let pathURL = profile.lastPath.flatMap { URL(string: $0, relativeTo: profile.origin)?.absoluteURL }
        let url = pathURL.flatMap { URLPolicy.sameOrigin($0, profile.origin) ? $0 : nil } ?? profile.origin
        load(url)
    }

    private func load(_ url: URL) {
        errorMessage = nil
        notice = nil
        isLoading = true
        webView.load(URLRequest(url: url))
    }

    func reload() {
        errorMessage = nil
        notice = nil
        isLoading = true
        if webView.url != nil { webView.reload() } else { load(profile.origin) }
    }

    func goHome() { load(profile.origin) }
    func stop() { widgetBridge?.stop(); webView.stopLoading() }
    func refreshWidget() { widgetBridge?.refresh() }
    func openWidgetRoute(_ path: String) {
        guard let url = URL(string: path, relativeTo: profile.origin)?.absoluteURL, URLPolicy.sameOrigin(url, profile.origin) else { return }
        started = true
        load(url)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              let source = message.frameInfo.request.url,
              URLPolicy.sameOrigin(source, profile.origin),
              let current = webView.url, URLPolicy.sameOrigin(current, profile.origin),
              Self.isSettingsRoot(current),
              let action = message.body as? String, action == "settings" else { return }
        serverSettingsRequests.send(())
    }

    private static func isSettingsRoot(_ url: URL) -> Bool {
        let parts = url.path.split(separator: "/")
        return parts == ["settings"] || (parts.count == 3 && parts[0] == "s" && parts[2] == "settings")
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        errorMessage = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        if let url = webView.url { onSafePath(url) }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }

    private func fail(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        isLoading = false
        switch (error as NSError).code {
        case NSURLErrorNotConnectedToInternet: errorMessage = "网络已断开，请检查连接后重试。"
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost: errorMessage = "无法连接服务器，请检查地址和网络。"
        case NSURLErrorTimedOut: errorMessage = "连接超时，请重试。"
        case NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorSecureConnectionFailed:
            errorMessage = "HTTPS 证书无法验证，请检查服务器证书。"
        default: errorMessage = "页面加载失败，请重试或修改服务器地址。"
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        isLoading = false
        errorMessage = "页面被系统释放，点重试恢复。"
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame, let response = navigationResponse.response as? HTTPURLResponse,
           !(200...299).contains(response.statusCode) {
            isLoading = false
            errorMessage = "服务器返回 HTTP \(response.statusCode)，请重试或回到首页。"
            decisionHandler(.cancel)
        } else if navigationResponse.isForMainFrame && !navigationResponse.canShowMIMEType {
            isLoading = false
            notice = "此文件暂不能在外壳中预览，请使用网页的分享或下载入口。"
            decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let isMain = navigationAction.targetFrame?.isMainFrame ?? true
        if !isMain { decisionHandler(.allow); return }
        if URLPolicy.sameOrigin(url, profile.origin) { decisionHandler(.allow); return }
        let scheme = url.scheme?.lowercased() ?? ""
        let userTriggered = navigationAction.navigationType == .linkActivated
        if userTriggered && ["http", "https", "mailto", "tel"].contains(scheme) {
            UIApplication.shared.open(url)
        } else {
            notice = "页面请求打开外部地址，已拦截。第三方登录需使用支持系统回调的版本。"
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        if URLPolicy.sameOrigin(url, profile.origin) { webView.load(navigationAction.request) }
        // External targets are handled by the navigation policy, once only.
        return nil
    }
}

// WKUserContentController retains handlers; keep the owner weak so changing
// deployments releases the previous browser and its WebKit data store.
@MainActor
private final class WeakConnectionHandler: NSObject, WKScriptMessageHandler {
    weak var owner: BrowserSession?
    init(_ owner: BrowserSession) { self.owner = owner }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.userContentController(controller, didReceive: message)
    }
}

extension BrowserSession {
    static let connectionSettingsScript = #"""
    (() => {
      if (location.origin !== new URL(raftConnectionOrigin).origin) return;
      const id = 'raft-app-connection-settings';
      let pending = false;
      const isSettingsRoot = () => /^\/(?:s\/[^/]+\/)?settings\/?$/.test(location.pathname);
      const render = () => {
        pending = false;
        const existing = document.getElementById(id);
        const list = isSettingsRoot() && document.querySelector('[data-testid="settings-sidebar-list"]');
        if (!list) { existing?.remove(); return; }
        if (existing && existing.parentElement === list) return;
        existing?.remove();
        const row = list.querySelector('button');
        if (!row) return;
        const chinese = document.documentElement.lang.toLowerCase().startsWith('zh');
        const label = chinese ? '服务器设置' : 'Server settings';
        const section = document.createElement('section');
        section.id = id;
        section.dataset.testid = 'app-connection-section';
        const heading = document.createElement('div');
        heading.className = row.parentElement.firstElementChild?.className || '';
        heading.textContent = chinese ? 'App 连接' : 'App connection';
        heading.style.marginTop = '20px';
        section.append(heading);
        {
          const button = document.createElement('button');
          button.type = 'button';
          button.className = row.className;
          // Preserve the row recipe, but never copy React-owned handlers,
          // identifiers, selected state, labels, or permission attributes.
          for (const key of ['data-slot', 'data-variant']) {
            if (row.hasAttribute(key)) button.setAttribute(key, row.getAttribute(key));
          }
          button.dataset.testid = 'app-connection-settings';
          button.setAttribute('aria-label', label);
          button.style.minHeight = '44px';
          button.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="flex-shrink:0">' + '<circle cx="12" cy="12" r="9"/><path d="M3 12h18 M12 3c-5 5-5 13 0 18 5-5 5-13 0-18"/>' + '</svg>';
          button.append(document.createTextNode(label));
          button.addEventListener('click', () => {
            if (isSettingsRoot()) window.webkit.messageHandlers.raftConnection.postMessage('settings');
          });
          section.append(button);
        }
        list.append(section);
      };
      const schedule = () => {
        if (!pending) { pending = true; requestAnimationFrame(render); }
      };
      new MutationObserver(records => {
        if (records.some(record => !record.target.closest?.('#' + id))) schedule();
      }).observe(document.documentElement, {childList: true, subtree: true});
      window.addEventListener('popstate', schedule);
      // SPA navigation can preserve the settings list while changing its route.
      for (const method of ['pushState', 'replaceState']) {
        const original = history[method];
        history[method] = function(...args) {
          const result = original.apply(this, args);
          schedule();
          return result;
        };
      }
      render();
    })();
    """#
}
