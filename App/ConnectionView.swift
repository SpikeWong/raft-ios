import SwiftUI

// Match the default Raft visual tokens without coupling the shell to Web CSS.
enum RaftPalette {
    static let yellow = Color(red: 1, green: 212.0 / 255, blue: 64.0 / 255)
    static let pink = Color(red: 254.0 / 255, green: 125.0 / 255, blue: 168.0 / 255)
}

struct RaftOutline: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .systemBackground))
            .overlay(Rectangle().strokeBorder(Color.primary, lineWidth: 2))
            .background(Color.primary.offset(x: 4, y: 4))
    }
}

struct RaftButtonStyle: ButtonStyle {
    var fill: Color = RaftPalette.pink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold)).foregroundStyle(Color.black)
            .padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: .infinity).background(fill)
            .overlay(Rectangle().strokeBorder(Color.primary, lineWidth: 2))
            .background(Color.primary.offset(x: configuration.isPressed ? 1 : 4,
                                            y: configuration.isPressed ? 1 : 4))
            .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
    }
}

struct ConnectionView: View {
    let initialAddress: String
    let isEditing: Bool
    let connect: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var error: String?
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isEditing ? "服务器设置" : "连接你的 Raft")
                        .font(.title2.weight(.black))
                    Text("RAFT / PERSONAL").font(.caption.monospaced()).tracking(1)
                }
                Spacer()
                if isEditing {
                    Button("取消") { dismiss() }
                        .font(.subheadline.bold()).foregroundStyle(.black)
                        .padding(10)
                        .overlay(Rectangle().strokeBorder(.black, lineWidth: 2))
                }
            }
            .foregroundStyle(.black).padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RaftPalette.yellow)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.primary).frame(height: 2) }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("使用熟悉的界面").font(.title3.bold())
                        Text("连接你的 Raft，继续聊天和处理任务。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Raft 网页地址").font(.headline.bold())
                        TextField("Raft 网页地址", text: $address,
                                  prompt: Text("https://raft.example.com").foregroundStyle(.secondary))
                            .font(.body.monospaced())
                            .foregroundStyle(Color.primary)
                            .textContentType(.URL).keyboardType(.URL)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($addressFocused)
                            .padding(14).frame(minHeight: 52)
                            .modifier(RaftOutline())
                            .accessibilityLabel("Raft 网页地址")
                            .accessibilityIdentifier("serverAddress")
                            .submitLabel(.go).onSubmit(submit)
                        Text("填写浏览器中打开 Raft 的根地址。")
                            .font(.footnote).foregroundStyle(.secondary)
                        if let error {
                            Text(error).font(.subheadline.bold()).foregroundStyle(.red)
                                .accessibilityIdentifier("addressError")
                        }
                    }
                    if let normalized = try? URLPolicy.normalize(address) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("将连接").font(.caption.bold()).foregroundStyle(.secondary)
                            Text(normalized.absoluteString).font(.subheadline.monospaced())
                                .textSelection(.enabled)
                            if normalized.scheme == "http" {
                                Text("本地 HTTP 连接；正式使用建议启用 HTTPS。")
                                    .font(.footnote).foregroundStyle(.orange)
                            }
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .modifier(RaftOutline())
                    }
                    Button("连接", action: submit)
                        .buttonStyle(RaftButtonStyle())
                        .accessibilityIdentifier("connectButton")
                        .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
                    Text("不同部署的登录数据分别保存在这台设备上。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(24).frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(uiColor: .systemBackground)).tint(.primary)
        .onAppear { address = initialAddress }
    }

    private func submit() {
        do { try connect(address); error = nil; addressFocused = false }
        catch { self.error = error.localizedDescription }
    }
}
