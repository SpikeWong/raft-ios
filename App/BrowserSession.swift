import Combine
import UIKit
import WebKit

@MainActor
final class BrowserSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let profile: ConnectionProfile
    let webView: WKWebView
    @Published var isLoading = true
    @Published var progress: Double = 0
    @Published var canGoBack = false
    @Published var errorMessage: String?
    @Published var notice: String?
    private var observations: [NSKeyValueObservation] = []
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
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
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
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoBack = view.canGoBack }
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
    func goBack() { if webView.canGoBack { webView.goBack() } }
    func stop() { webView.stopLoading() }

    func clearData() async {
        stop()
        let store = webView.configuration.websiteDataStore
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
                continuation.resume()
            }
        }
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
