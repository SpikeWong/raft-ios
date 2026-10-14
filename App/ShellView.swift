import SwiftUI
import WebKit

struct RaftWebView: UIViewRepresentable {
    let session: BrowserSession
    func makeUIView(context: Context) -> WKWebView { session.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) { }
}

struct BrowserView: View {
    @ObservedObject var session: BrowserSession
    let edit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if session.isLoading { ProgressView(value: session.progress).progressViewStyle(.linear) }
            if let notice = session.notice {
                HStack {
                    Text(notice).font(.caption)
                    Spacer()
                    Button { session.notice = nil } label: { Image(systemName: "xmark") }.accessibilityLabel("关闭提示")
                }.padding(10).background(Color.orange.opacity(0.12))
            }
            ZStack {
                RaftWebView(session: session)
                if let message = session.errorMessage {
                    Color(uiColor: .systemBackground)
                    VStack(spacing: 18) {
                        Image(systemName: "network.slash").font(.largeTitle).foregroundStyle(.secondary)
                        Text("暂时无法打开 Raft").font(.headline)
                        Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            .accessibilityIdentifier("loadError")
                        Button("重试", action: session.reload).buttonStyle(.borderedProminent).accessibilityIdentifier("retryButton")
                        Button("回到首页", action: session.goHome).buttonStyle(.bordered)
                        Button("修改服务器地址", action: edit)
                    }.padding(28)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onReceive(session.serverSettingsRequests) { _ in edit() }
        .onAppear { session.start() }
    }
}

struct ShellView: View {
    @StateObject private var model = ShellModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let browser = model.browser {
                BrowserView(session: browser, edit: { model.editingConnection = true })
            } else {
                ConnectionView(initialAddress: "", isEditing: false, connect: model.connect)
            }
        }
        .onOpenURL { model.openWidget($0) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.browser?.refreshWidget() }
        }
        .sheet(isPresented: $model.editingConnection) {
            ConnectionView(initialAddress: model.browser?.profile.origin.absoluteString ?? "", isEditing: true, connect: model.connect)
        }
    }
}
