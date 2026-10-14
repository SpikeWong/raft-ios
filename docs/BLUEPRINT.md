# Raft iOS 产品与架构基线

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


---

# 产品需求 v0.1

日期：2026-10-11。范围：个人 iPhone 使用；首版 MVP。

## 目标

用户在 iPhone 上打开自己的 Raft，保持现有手机 UI，可以收发消息、查看线程和任务；退出再打开时保留部署配置和登录状态。用户可以更换部署地址，不需要重新编译 App。

成功标准：完成“填地址 → 登录 → 打开频道 → 发消息 → 查看回复 → 切后台再回来”的完整流程。首版开发以文档驱动，交付可打开的 Xcode 工程与功能账簿；测试证据在项目外保存。

## 已知事实与待确认

目标网页应提供手机布局、用户登录与消息同步。原生外壳不会补全目标部署缺失的业务功能。

需要一个可用的 Raft Web 部署。登录、消息与附件行为须在目标部署和真实 iPhone 上验证；示例域名仅作说明。

## 核心流程

1. 首次启动进入“连接你的 Raft”。输入 Raft **网页地址**，界面显示规范化后的地址。
2. 点“连接”，加载该部署现有手机 Web UI；登录使用网页原有表单。
3. 聊天/任务/成员/设置导航仍由 Web 提供；连接后不显示顶部网址栏；外壳不显示常驻连接菜单，不加第二套底部导航。网页延伸到屏幕底部，由 Web 处理底部导航安全区域。
4. 在 Settings 的“App 连接”区域修改服务器地址；使用站内列表样式。
5. 正常重开恢复配置与登录。加载失败可重试或改地址，不删除登录。
6. 更换网络部署时使用独立数据存储；再次回到该部署时可恢复其登录。

## 首版需求

| 编号 | 优先级 | 要求 |
|---|---|---|
| FR-01 | P0 | 配置页沿用 Raft 的黄色顶栏、粗边框、硬阴影和字体层级；输入与保存部署网页地址，无需编译；支持 HTTPS 和本地开发 HTTP，明确拒绝非法地址 |
| FR-02 | P0 | 直接展示现有手机 Web UI，不重写页面、任务模型或消息同步 |
| FR-03 | P0 | 保留登录；不同部署使用独立存储 |
| FR-04 | P0 | Settings 只提供服务器地址设置；支持网页新窗口与外链的明确处理 |
| FR-05 | P0 | 显示首次加载、网络/HTTP 错误与重试；临时失败不触发登出 |
| FR-06 | P0 | 不破坏 Web 草稿、频道导航、滚动和输入；前台恢复时沿用 Web 重连，不强制刷新 |
| FR-07 | P0 | 适配键盘、安全区域、暗色模式和 iPhone 横竖屏；不默认启用桌面 UI |
| FR-08 | P1 | 用 Web 原有文件选择上传附件；真机验证照片/文件输入行为 |
| FR-09 | P0 | HTTPS 正常证书校验；外壳不保存或显示密码/token，不向新部署转发原部署凭据 |
| FR-16 | P1 | App 使用独立的通用连接图标，包含 iPhone/iPad 主屏幕与分发图标资产 |

## 首版边界

- 地址输入是 **Web URL**，不是 API URL，也不是 Raft Server slug。网页已有正确的 `VITE_API_URL` 或同源 API 配置时，外壳可直接工作。
- 不提供一个实际不生效的“独立 API 地址”输入框。若确需运行时改 API/Socket 地址，作为后续 Web 适配需求（FR-14）实现并联调。
- 首版以网页提供的账号密码/验证码登录为验收路径。Google/GitHub OAuth 需要核对系统浏览器回调合同，不宣称“只包 WebView 就都支持”。
- 首版不接原生 APNs、不做后台常驻连接、不做离线收发、不发布应用。
- 重开恢复登录；草稿按 Web 自身规则恢复。跨进程恢复到上次频道仅保存无查询参数的同源路径，敏感回调不记录。

## 后续版本

| 编号 | 功能 | 依赖 |
|---|---|---|
| FR-10 | DM、@提及、关注线程的 APNs 通知与角标 | 独立 App 身份、服务端 APNs 配置/开关、设备注册和撤销 |
| FR-11 | 通知点击准确定位 Server/频道/线程/消息 | 登录和目标 Server 就绪；权限校验；去重 |
| FR-12 | 系统分享入口、附件下载预览 | 原生 Share Extension/下载合同 |
| FR-13 | 外部 OAuth 登录 | 系统认证会话、后端允许的回调和一次性交接 |
| FR-14 | 独立 API/Socket 地址运行时配置 | Web 适配与 CORS/Origin/版本合同，不能仅修改外壳 |
| FR-15 | 本地 H5 资源加速启动 | 前端 host 清单、完整性校验、兼容性和回退 |

## 验证原则

模拟器可以证明外壳流程、存储、路由和布局工作，不能代替目标部署的登录、消息/附件或真实锁屏推送验收。当前实现范围详见 [FEATURELIST.md](FEATURELIST.md)，验证报告在项目外保存。

## Widget（0.2.0）

FR-17：提供 iPhone 桌面小号／中号 Widget，展示当前协作空间可见任务的待办、进行中、待审核数量，未读消息／Activity 通知，以及最近任务与最后同步时间。点任务或通知进入 App 对应页面。没有数据、未登录、请求失败、数据过期分别表达，未知数字显示“—”，不能伪装成零。

网页登录仍是唯一认证所有者。App 前台以当前网页会话读取同源 API，只把经校验的计数、任务摘要、配置标识和时间共享给 Widget；不共享 access/refresh token。切换部署或注销时清除旧摘要。Widget 展示最近一次 App 同步的快照，不提供独立后台登录或 APNs 实时通知。WidgetKit 调度刷新；历史快照超过 15 分钟显示“打开 App 更新”。


## FR-18 附件预览高度兼容

2026-10-13：用户截图显示竖图附件越过预览框、遮住输入框。个人外壳对同源主页面注入局部 CSS，使图片附件的悬停／拖动容器继承预览框高度。保持 Web 的颜色、尺寸和拖动／删除功能，不修改 Raft Web 或部署后端。成功标准：竖图、方图、横图都留在原预览框中；草稿不被覆盖，删除按钮仍可点击，普通文件卡片保持原布局。


## FR-19 首页触摸防误触

2026-10-13：用户反馈首页容易意外切换 tab 和 Agent 排序。关闭 WebView 的边缘前进／后退手势，保留网页 tab 按钮和显式返回按钮。仅在 Sidebar 可排序项内，触摸 pointerdown 不启动即时 PointerSensor；既有 TouchSensor 按住约500ms的路径保留。短滑动允许页面滚动，普通点按仍打开对应项，鼠标／键盘排序和菜单按钮保持原行为。


---

# Architecture v0.1

## 结构

```mermaid
flowchart LR
  U[用户] --> S[SwiftUI 外壳]
  S --> C[连接配置与地址策略]
  S --> W[持久 WKWebView]
  C --> D[每个部署独立 WKWebsiteDataStore]
  D --> W
  W --> H[现有 Raft 手机 Web]
  H --> A[Web 已配置的 REST API]
  H --> R[Socket.IO 与同步]
  H --> B[可选 RaftHost 生命周期事件]
  B --> S
```

只有 Web 发业务请求；外壳首版不复制 REST SDK、消息库或 token 刷新。外壳通过系统 WebKit 打开真实网页，页面内容随 Web 部署更新。

## 模块职责

| 模块 | 职责 |
|---|---|
| `ConnectionProfile` / `URLPolicy` | 规范化地址、限制方案、识别同源、决定导航去向 |
| `ConnectionStore` | 保存当前配置、部署到 dataStore UUID 的映射、可恢复路径；不存凭据 |
| `BrowserSession` | 长寿命 WKWebView、KVO 状态、加载错误、返回/重试、进程终止恢复 |
| `RaftWebView` | 把现有 WebView 挂到 SwiftUI；视图刷新不重建浏览器 |
| `ConnectionView` | 配置地址与输入错误；保留之前可用的连接 |
| `ShellView` | 加载/错误状态、Settings 连接操作、安全区域和应用生命周期 |

## App 图标

`App/Assets.xcassets/AppIcon.appiconset` 保存 1024px 不透明 PNG，复用 Raft 现有黄色品牌资源。Xcode 资产编译器生成系统需要的图标尺寸；不预裁圆角，不引入图片生成服务或运行时下载。

## 状态与生命周期

`未配置 → 编辑配置 → 加载 → 浏览`；加载失败进入 `可重试错误`，但保留配置和 Web 数据。

- 正常浏览时不提供外壳刷新按钮；加载错误页保留重试和回首页以恢复连接，不在每次前台恢复时自动刷新。
- 进入后台不自行断开或维护 Socket；Web/iOS 决定暂停，返回前台交给现有 Web 的同步重连。
- WKWebView 必须保存在长寿命 `BrowserSession` 中，不随着 SwiftUI body/菜单变化重建。
- Web 内容进程被系统终止时，展示恢复入口或恢复最近的安全同源路径，避免死循环重载。
- 更换部署先结束旧浏览器，新的连接使用新部署的持久存储。旧部署登录留在其专属存储中。

## 登录与数据隔离

最低系统版本：**iOS 17**，采用 `WKWebsiteDataStore(forIdentifier:)` 对每个规范化 Web origin 建立独立持久存储。保留 Web 自身 token/cookie 管理，不将其导出到 UserDefaults、日志或分享面板。

原生不注入密码，不实现第二套刷新。注销使用 Web 原有注销；外壳不提供清除连接数据操作。

同一 origin 的多个 Raft 协作空间由 Web 管理，不人为分裂登录；不同 origin 的部署不会共享 cookie/localStorage。

## 地址与部署

首版配置一个 Web origin。输入完整 URL，或省略协议时补 HTTPS。HTTPS 支持域名/IPv4/IPv6/自定义端口；HTTP 仅限环回、明确的私有 IP 和本地名称。路径入口和恢复路由与 origin 分开，不把敏感 URL 存入配置。

API 可能与 Web 不同源，由该网页现有构建配置控制。首版不能靠 `window.location` 或拦截所有 fetch 来“替换 API”；那会让 REST、认证与 Socket 各走不同路径。若用户需要运行时 API 选择，增加显式 Web 环境合同，并在网页启动前验证和应用，另立 ADR。

## 原生与 Web 边界

连接后不占用顶部整条网址栏；Settings 根列表增加“App 连接”区域，只提供服务器设置，不显示常驻三点菜单。WKWebView 延伸至容器底部，由 Web 的 safe-area 处理底部导航；键盘安全区域仍由 SwiftUI 处理。UIKit 的自动 scroll inset 关闭，避免再次扣掉 home indicator 高度。Web 拥有产品导航。`window.RaftHost` 可用于单向生命周期通知，安装在 document start、仅主 frame。不要注入 `__TAURI_INTERNALS__` 或冒充 Desktop 环境，否则会触发官网生产/staging 地址验证。

普通同源导航留在 WebView。外部普通链接交给系统浏览器；网页新窗口按链接策略处理；OAuth 不能沿用普通外链处理声称已经支持。未知 scheme 不执行，系统电话/邮件链接由明确列表允许。

连接设置使用独立 raftConnection 消息桥，只接受当前部署主 frame 的服务器设置动作，不接受地址、凭据或任意原生命令。外壳不根据桥接消息发送推送、登出其他设备或更改数据。

设置入口通过 document-end 主 frame 脚本挂载到 `[data-testid="settings-sidebar-list"]`，复用现有行的样式与主题。只在 `/settings` 或 `/s/<slug>/settings` 根页显示；MutationObserver 处理 SPA 重绘与导航，避免重复挂载。此处新增一项明确的 Web DOM 合同；若上游移除该入口，需要适配，网络错误页仍可修改地址。打开与取消地址设置不重建 WebView，不刷新网页。桥接代理弱引用浏览器，防止循环持有。

## 失效与诊断

- 初次导航非成功 HTTP 状态、DNS/连接失败、证书错误都显示可重试提示；不自动删除登录。
- iOS 正常处理 TLS 验证，不能通过接受所有 authentication challenge 绕过证书。
- 诊断只记录状态与错误分类，不记录 URL 查询参数、请求正文或身份 token。
- 使用受控测试网页验证外壳；真实 Raft 联调使用用户指定部署，不替其部署前端或修改生产配置。

## 推送扩展

后续 `PushCoordinator` 负责通知授权、设备 token 和点击路由；后端负责注册、撤销、APNs 投递。若用户只拥有官网协作空间，需要先确认平台允许个人 App 的推送身份；不可直接复用官方 App 的签名/推送凭据。

## 源码依据

相关 Raft Web / 服务端源码位置：

- `packages/web/src/store/mobileNavStore.ts`、`components/layout/LeftRail.tsx`：手机导航。
- `packages/web/src/api/client.ts`、`api/socket.ts`、`desktopRuntimeEnvironment.ts`：REST/Socket 地址和 Web token 所有权。
- `packages/web/src/embed/hostBridge.ts`：`raft-host-v1` 事件合同。
- `packages/web/h5-bundle.config.json`：hosts 为空，不能宣称离线原生资源包就绪。
- `packages/server/src/routes/push.ts`、`services/pushService.ts`：原生推送注册/撤销/APNs 配置和功能开关。

Apple：[WebKit 数据存储](https://developer.apple.com/documentation/webkit/wkwebsitedatastore)、[WKNavigationDelegate](https://developer.apple.com/documentation/webkit/wknavigationdelegate)。

## Widget

WidgetKit extension 与 App 共享 Foundation 模型和 SwiftUI 摘要布局。App从当前 WebView 的同源 GET 请求获取摘要（token 只在网页内部使用），通过 raftWidgetSnapshot 主frame桥提交经过字段和范围校验的快照。AppGroup写文件采用原子替换，Widget无网络／凭据访问。前台30秒一次、完成页面导航和回到前台时同步；切换部署先清摘要，迟到的旧网页响应不能覆盖新配置。Widget timeline 负责在15分钟后切换为过期提示；点链接通过当前profile检查回到Web路由。签名App与extension共用AppGroup，默认group.com.example.raftpersonal。


### 图片附件兼容

ComposerPreviewStyle 作为局部同源主 frame 样式修正，补齐 Web 图片附件拖动容器的百分比高度传递。使用既有语义 data-slot，不改变服务端、消息发送或图片上传行为。样式独立于 Web 的主题和上传逻辑；后续 Web 消除该结构问题时可移除此兼容层。


### FR-19 触摸行为

HomeTouchPolicy 只在连接 origin 的主 frame 安装，只处理触摸 pointerdown 且目标处于 data-sidebar-drag-item 内；不 preventDefault、不处理 touchstart，所以网页的长按触摸传感器及点按、滚动继续工作。输入控件和菜单触发按钮不匹配该拦截。WebView 边缘历史手势关闭；页面的 tab 与返回按钮继续由 Web 管理。验证结果另放工作区报告。


---

# 接口与行为合同 v0.1

## 地址合同

输入字段：`部署网页地址`。持久化：规范化 origin、该 origin 的稳定 UUID、可恢复页面路径。首版不保存用户密码、access token、refresh token 或带查询参数的地址。

| 输入 | 行为 |
|---|---|
| `raft.example.com` | 补为 `https://raft.example.com` |
| `https://raft.example.com:8443/` | 保留端口，规范化为 origin |
| `http://192.168.1.20:3000` | 本地开发允许；界面提示该连接使用 HTTP |
| `https://user:password@host` | 拒绝嵌入式凭据 |
| `javascript:` / `file:` / 缺少 host / 空输入 | 拒绝 |
| HTTPS URL 带路径、query、fragment | 首版要求部署根地址，提示填写根地址；路由由网页自行管理 |
| `http://public.example.com` | 拒绝，要求 HTTPS |

origin 的等价性包括协议、规范化 host 和有效端口；默认端口省略。IPv6 使用 Foundation 的 URL/URLComponents 解析，不以冒号分割字符串。

## 导航合同

- 同源主 frame：允许 Web 管理导航。
- 外部 HTTP(S) 用户点击：系统浏览器打开；不会将任何 Web 登录 token附加到 URL。
- 外部自动重定向：拦截并告知；不自动跳出 App。
- `target=_blank`：同源在现有 WebView 打开，外部交系统。
- `mailto` / `tel`：只有用户触发时交系统；其他 scheme 拒绝。
- 普通 iframe/subresource 不执行“跳出 App”，资源网络控制交给 WebKit/CSP。
- 不把“外链已打开”当成“OAuth 登录已完成”。FR-13 的系统认证会话与回调仍未实现。

## 存储与恢复合同

每个规范化部署 origin 映射一个稳定 dataStore UUID；重开连接继续使用它。改到其他 origin 不复制原来的 Web 存储。外壳不提供清除连接数据入口；注销使用网页原有功能。

最近路径仅在正常网页导航完成后保存：同源，非 `/auth/` 等敏感认证路由，不含 query/fragment。重开优先加载该路径，否则根路径。恢复导航失败可回根路径；不无限循环。

## App 连接设置

只在 Settings 根页的 `settings-sidebar-list` 中显示 App 连接操作；其他页面没有外壳悬浮按钮。现有网页列表行提供主题样式，原生只负责服务器地址设置。地址设置取消后继续使用同一 WebView。

`window.webkit.messageHandlers.raftConnection` 只接收固定字符串 `settings`。只接受当前配置 origin 的主 frame 且当前页面仍在 Settings 根路径；未知消息和子 frame 均忽略，不接收任意 URL、脚本或 token。

## 可选 `raft-host-v1` 桥

如果安装，采用既有 `window.RaftHost = {version: 'raft-host-v1', emit(kind, payload)}`；只接受主 frame 和当前配置 origin 的消息。

允许观察 `session:logout`、`session:server-switched`、`session:server-left`、`session:server-deleted`、`session:token-refresh-failed`。这些事件不是授权原生发送业务请求的命令。对未实现的 onboarding 能力不注入 `onboarding` 属性。

首版允许不安装桥；无桥时 Web 正常运行。产品功能不依赖桥被检测到。

## 后续独立 API 合同

只有实现 FR-14 后才显示 API 设置。必须由前端显式消费经过验证的原生环境配置，同时约束 REST、token refresh、OAuth 与 Socket origin。不得复用 Desktop 固定官网环境对象，不做通用 XHR/fetch URL 重写。切换网络后端需切换存储 generation，防止同一 Web origin 的旧后端登录凭据发给新 API。

## 版本与发布

首版系统 iOS 17+。交付 Xcode 工程、模拟器可运行构建和功能账簿。验证结果另行报告，不放项目。用户选择签名 Team 后可真机安装；不包含自动上传/发布 TestFlight，也不把模拟器 `.app` 当成 iPhone 可安装包。

## Widget 数据合同

App Group 的 widget-snapshot.json 保存版本、profile UUID、状态、serverSlug/name、todo/inProgress/inReview、unreadMessages/unreadActivity、最多三条最近任务（标题最多120字、状态、数字）及同步时间。字段白名单；不保存用户标识、凭据、消息正文、任意 URL。仅接受当前 origin 主 frame 的有限 JSON，限制16KB；数据校验失败拒绝。同步过程只 GET，不修改任务/已读状态，不运行第二套 token refresh。当前实现支持与 Web 同源的 /api；接口失败显示不可用，不猜测 API 地址。

Widget 点击 raftpersonal://widget?profile=<UUID>&server=<slug>&section=tasks|activity 只在 profile 等于当前活动配置且 slug 格式合法时导航；忽略外部 URL、非法动作和旧部署链接。任务列表使用可见任务分页摘要，读取上限2500项，超过上限显示计数下限标记。Widget只展示共享快照，15分钟后提示更新。AppGroup命名通过RAFT_APP_GROUP_ID统一配置，App和extension必须签名到同一个Team且启用相同Group。


## 附件预览兼容样式

只在当前连接 origin 的主 frame 注入 ComposerPreviewStyle。选择器限定有 composer-attachment-image 子项的 composer-attachment 直接悬停／拖动容器，继承父预览框的宽高；不读取附件内容、不修改草稿，不增加网页消息动作或请求。图片卡片继续由 Web 拥有颜色、固定尺寸、裁切、上传、删除与拖动；普通文件卡片不匹配兼容选择器。SPA 重绘后样式继续生效。


### FR-19 触摸行为

HomeTouchPolicy 只在连接 origin 的主 frame 安装，只处理触摸 pointerdown 且目标处于 data-sidebar-drag-item 内；不 preventDefault、不处理 touchstart，所以网页的长按触摸传感器及点按、滚动继续工作。输入控件和菜单触发按钮不匹配该拦截。WebView 边缘历史手势关闭；页面的 tab 与返回按钮继续由 Web 管理。验证结果另放工作区报告。


---

# Featurelist — 功能账簿

目标：保持一个最简、随 Web 升级的 iOS 外壳。本期不接 OAuth；功能范围与实现状态记录在此。

状态定义：`开发中`、`已实现`、`后续`。已实现只表示代码具备该功能；真实部署和真机验证结果单独报告。

## 首版

| 编号 | 功能 | 状态 | 实现位置 / 边界 |
|---|---|---|---|
| FR-01 | 自定义 Raft 网页根地址 | 已实现 | URLPolicy、ConnectionView；配置页沿用站内默认视觉，不覆盖网页的 API 配置 |
| FR-02 | 复用现有手机 UI | 已实现 | BrowserSession、RaftWebView；不复制 Raft 产品导航/消息逻辑 |
| FR-03 | 每个部署独立持久登录 | 已实现 | ConnectionStore、WebKit 专属数据存储 |
| FR-04 | 服务器设置、外链 | 已实现 | BrowserSession、BrowserView；连接后无网址栏，Settings 根页的 App 连接列表提供操作，没有常驻菜单 |
| FR-05 | 加载/HTTP/网络错误恢复 | 已实现 | BrowserSession；失败不清登录 |
| FR-06 | 保留 WebView 与页面内状态 | 已实现 | ShellModel；前台不强制刷新，重开恢复安全路径 |
| FR-07 | 键盘、安全区域和系统主题 | 已实现 | SwiftUI + WebKit；Web 负责底部 safe-area，外壳不重复补边距；产品主题仍由网页控制 |
| FR-08 | Web 原有照片/文件上传入口 | 开发中 | 用户报告真机上传失败，正在定位；系统文件 input 不等于真实上传链路已验证；原生下载/分享后续 |
| FR-09 | 地址限制、证书校验与凭据边界 | 已实现 | URLPolicy、系统 TLS；原生不管理用户 token |
| FR-16 | Raft App 图标 | 已实现 | Assets.xcassets/AppIcon；使用独立的通用连接图标，系统处理圆角 |

## 后续 / 明确不做

| 编号 | 功能 | 状态 | 进入条件 |
|---|---|---|---|
| FR-10/11 | APNs、角标、通知定位 | 后续 | 自有 App 身份及后端支持 |
| FR-12 | 原生分享/附件下载预览 | 后续 | 用户有实际需求 |
| FR-13 | OAuth | 后续，本期不接 | 用户重新确认需求，并定义系统回调合同 |
| FR-14 | 独立 API/Socket 地址覆盖 | 后续 | 单一 Web 地址不足以满足部署方式 |
| FR-15 | 本地 H5 包 | 后续 | 在线加载性能确有问题；否则不引入更新链 |

## 升级约定

- raft-source 更新后，Web 按原地址部署，外壳自动加载新版；通常无需发新 iOS 包。
- 连接设置入口依赖 Settings 根页的 settings-sidebar-list 标记，并复用现有列表行样式；该 DOM 合同变化时需要适配。消息/API/Socket 和认证仍由 Web 管理；不注入 RaftHost 桥。
- Web 的认证方式/域名变化，或者新增原生能力时，重新评估合同；不能承诺任何上游变化都零适配。

## Widget（0.2.0）

FR-17：提供 iPhone 桌面小号／中号 Widget，展示当前协作空间可见任务的待办、进行中、待审核数量，未读消息／Activity 通知，以及最近任务与最后同步时间。点任务或通知进入 App 对应页面。没有数据、未登录、请求失败、数据过期分别表达，未知数字显示“—”，不能伪装成零。

网页登录仍是唯一认证所有者。App 前台以当前网页会话读取同源 API，只把经校验的计数、任务摘要、配置标识和时间共享给 Widget；不共享 access/refresh token。切换部署或注销时清除旧摘要。Widget 展示最近一次 App 同步的快照，不提供独立后台登录或 APNs 实时通知。WidgetKit 调度刷新；历史快照超过 15 分钟显示“打开 App 更新”。


- FR-18 图片附件预览高度：0.2.1（7）补齐图片拖动容器的高度继承；普通文件、移除按钮与草稿布局保持原行为。验收记录放工作区报告。真机上传请求问题仍独立跟进，不以预览修正代替上传验收。


### FR-19 触摸行为

HomeTouchPolicy 只在连接 origin 的主 frame 安装，只处理触摸 pointerdown 且目标处于 data-sidebar-drag-item 内；不 preventDefault、不处理 touchstart，所以网页的长按触摸传感器及点按、滚动继续工作。输入控件和菜单触发按钮不匹配该拦截。WebView 边缘历史手势关闭；页面的 tab 与返回按钮继续由 Web 管理。验证结果另放工作区报告。


---

# ADR 0001：复用手机 Web，原生只管理连接和系统能力

日期：2026-10-11。状态：方案由用户批准；细节形成 v0.1 实施基线。

## 背景

用户希望 iOS 界面与现有 Raft 一致、方便个人使用，并能配置部署地址。已有 Web 具备手机布局、复杂消息渲染、认证与同步。公开源码未包含官方 iOS 原生工程。

## 决策

- SwiftUI 外壳 + 持久 WKWebView，在线加载用户指定 Web 部署。
- iOS 17 起，按部署 origin 使用独立持久 WebKit 数据存储。
- 认证、token刷新、Socket.IO 和产品导航继续由 Web 拥有。
- 首版只配置 Web 地址；API 地址由 Web 部署控制。运行时 API 覆盖要实现显式 Web 合同后才开放。
- 不修改原始 raft-source，不依赖官方测试版支持自建服务器。

## 考虑过的选择

| 选择 | 结果 |
|---|---|
| 重写 SwiftUI 聊天/任务 UI | 会复制导航、渲染、同步和认证逻辑，UI 维护成本高 |
| 跨平台框架再重写 UI | 仍然需要追踪现有 Web 行为，不利于界面持续一致 |
| Capacitor 打包整个 Web | 可行，但首版已有在线网页可复用；额外引入构建/插件链暂无必要 |
| 原生在线 WebView | 能直接保留 UI，实现地址选择与系统能力，符合个人首版目标 |
| 仅使用 PWA/官方 App | 可用于日常体验；用户明确选择开发可配置地址的独立外壳 |

## 后果

首版依赖网络与目标 Web 版本；Google 等 OAuth 不能假设在内嵌网页可用。原生推送仍需 App 身份与后端配置。独立数据存储要求最低 iOS17。网页升级会直接影响 App，因此联调必须针对用户实际部署，不仅针对源码快照。
