# Raft Personal iOS

一个可配置部署地址的非官方 Raft iOS 客户端：在线加载现有 Raft 手机 Web UI，原生负责连接配置、网页生命周期、系统导航与只读 Widget 摘要。

## 项目范围

- SwiftUI + WKWebView，最低 iOS 17；不包含或修改 Raft Web / 服务端源码。
- 只配置网页根地址；API、Socket、认证与产品导航由目标网页负责。
- 不注入 RaftHost，不重写登录或消息同步，不接 APNs 或外部 OAuth 回调。
- Settings 服务器设置、Widget 摘要、附件预览与触摸策略依赖文档化的网页 DOM/API 合同；网页合同变化需要重新评估。
- Widget 使用同源只读 API 和 App Group 摘要；不在扩展中保存认证信息或独立登录。
- Bundle Identifier 使用通用示例，签名 Team 由使用者本地配置。

## 文档入口

1. [产品需求](docs/PRD.md)
2. [架构](docs/ARCHITECTURE.md)
3. [接口约定](docs/CONTRACTS.md)
4. [功能账簿](docs/FEATURELIST.md)
5. [架构决策](docs/adr/0001-web-shell.md)

## 术语

- **部署地址**：实际打开的 Raft Web 根地址，例如 `https://raft.example.com`。
- **API 地址**：网页配置的后端地址，可能与网页不同源。
- **Raft Server**：账号内的协作空间，不是网络服务器地址。
- **连接配置**：部署 origin、独立 WebKit 数据存储标识和安全恢复路径。
- **会话**：网页登录状态。

## 实施约定

- 功能实施前更新需求；边界变化同步架构、合同和功能账簿。
- 未验证的真实部署行为不能写成已完成；照片/文件上传仍需联调。
- 原生不保存或导出密码、token、cookie 或私有部署测试数据。
- 不提交个人域名、签名配置、凭据、本机路径、设备标识或构建产物。
