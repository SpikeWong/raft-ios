# Raft iOS

可配置部署地址的非官方 Raft iOS 客户端。使用 SwiftUI + WKWebView，直接加载已有的手机 Web UI，不复制聊天、登录或消息同步逻辑。

需要 iOS 17+、支持该 SDK 的 Xcode，以及一个可用的 Raft Web 部署。示例域名 `https://raft.example.com` 仅作说明。

## 运行

1. 打开 `RaftPersonal.xcodeproj`，选择 `RaftPersonal` scheme。
2. 模拟器可直接运行。真机在 Signing & Capabilities 选择自己的 Team，并将 Bundle Identifier 改成自己的唯一标识。
3. 首次打开填写 Raft **网页根地址**；登录在网页内完成。
4. 右上角连接菜单提供返回、刷新、首页、服务器设置与清除当前连接数据。不同部署使用独立持久存储。

原生 App 不设置独立 API / Socket 地址；这些地址由网页自身配置。没有 APNs、后台常驻连接、外部 OAuth 回调或原生附件下载。照片/文件上传仍需在实际部署和真机上验证。

## 开发

工程不依赖第三方原生库。产品范围和实现状态见 [功能账簿](docs/FEATURELIST.md)，设计入口见 [CONTEXT.md](CONTEXT.md) 和 [产品与架构基线](docs/BLUEPRINT.md)。

重建工程文件引用：

```sh
python3 scripts/generate_project.py
```

生成脚本会重建工程配置，包括本地签名设置；执行后需重新选择自己的 Team。请勿提交个人 Team、签名描述文件或证书。

无需签名的构建检查：

```sh
xcodebuild -project RaftPersonal.xcodeproj -scheme RaftPersonal \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
```

在 macOS 运行地址策略和配置持久化测试：

```sh
swift test
```

完整 UI 测试先启动 `python3 scripts/fixture_server.py`（仅监听本机端口 8767），再选择一个可用 iPhone 模拟器运行 Test。UI 测试尚未完成执行，不应视为已通过。模拟器构建不能安装到真实 iPhone。

## 图标与许可

公共版本使用独立的通用连接图标，位于 `App/Assets.xcassets/AppIcon.appiconset`。可用 `xcrun swift scripts/generate_icon.swift` 重新生成。修改图标后需重新构建并安装 App。

本仓库代码和通用图标采用 [MIT 许可](LICENSE)。不包含 Raft Web / 服务端代码或上游品牌图标，也不代表官方客户端。Raft 名称用于说明兼容目标。
