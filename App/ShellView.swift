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
    let clear: () -> Void

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
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("返回", systemImage: "chevron.left", action: session.goBack)
                    .disabled(!session.canGoBack)
                Button("刷新", systemImage: "arrow.clockwise", action: session.reload)
                Button("回到首页", systemImage: "house", action: session.goHome)
                Button("服务器设置", systemImage: "network", action: edit)
                Divider()
                Button("清除当前连接数据", systemImage: "trash", role: .destructive, action: clear)
            } label: {
                Image(systemName: "ellipsis").font(.body.bold())
                    .foregroundStyle(Color.primary)
                    .frame(width: 36, height: 32)
                    .background(Color(uiColor: .systemBackground))
                    .overlay(Rectangle().strokeBorder(Color.primary, lineWidth: 2))
                    .padding(6).contentShape(Rectangle())
            }
            .accessibilityLabel("连接菜单").accessibilityIdentifier("connectionMenu")
            .padding(.top, 4).padding(.trailing, 6)
        }
        .onAppear { session.start() }
    }
}

struct ShellView: View {
    @StateObject private var model = ShellModel()
    @State private var confirmingClear = false

    var body: some View {
        Group {
            if model.clearingData {
                ProgressView("正在清除当前连接数据…")
            } else if let browser = model.browser {
                BrowserView(session: browser, edit: { model.editingConnection = true }, clear: { confirmingClear = true })
            } else {
                ConnectionView(initialAddress: "", isEditing: false, connect: model.connect)
            }
        }
        .sheet(isPresented: $model.editingConnection) {
            ConnectionView(initialAddress: model.browser?.profile.origin.absoluteString ?? "", isEditing: true, connect: model.connect)
        }
        .confirmationDialog("清除当前部署在本机的登录与网页数据？", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("清除当前连接数据", role: .destructive) { Task { await model.clearCurrentData() } }
        } message: { Text("其他部署的数据会保留。当前部署需要重新登录。") }
    }
}
