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

每个规范化部署 origin 映射一个稳定 dataStore UUID；重开连接继续使用它。改到其他 origin 不复制原来的 Web 存储。清除当前连接时只删除该连接的 WebKit 数据，其他配置/会话不变。

最近路径仅在正常网页导航完成后保存：同源，非 `/auth/` 等敏感认证路由，不含 query/fragment。重开优先加载该路径，否则根路径。恢复导航失败可回根路径；不无限循环。

## 可选 `raft-host-v1` 桥

如果安装，采用既有 `window.RaftHost = {version: 'raft-host-v1', emit(kind, payload)}`；只接受主 frame 和当前配置 origin 的消息。

允许观察 `session:logout`、`session:server-switched`、`session:server-left`、`session:server-deleted`、`session:token-refresh-failed`。这些事件不是授权原生发送业务请求的命令。对未实现的 onboarding 能力不注入 `onboarding` 属性。

首版不安装桥；无桥时 Web 正常运行。后续接入桥时需要另行实现并验证上述合同。

## 后续独立 API 合同

只有实现 FR-14 后才显示 API 设置。必须由前端显式消费经过验证的原生环境配置，同时约束 REST、token refresh、OAuth 与 Socket origin。不得复用 Desktop 固定官网环境对象，不做通用 XHR/fetch URL 重写。切换网络后端需切换存储 generation，防止同一 Web origin 的旧后端登录凭据发给新 API。

## 版本与发布

首版系统 iOS 17+。交付 Xcode 工程、模拟器可运行构建和功能账簿。验证结果另行报告，不放项目。用户选择签名 Team 后可真机安装；不包含自动上传/发布 TestFlight，也不把模拟器 `.app` 当成 iPhone 可安装包。
