
# ProxyPin 项目结构分析

## 项目概览

**ProxyPin** 是一个基于 **Flutter** 开发的开源免费抓包工具（HTTP(S) 流量捕获），支持 Windows、Mac、Android、iOS、Linux 全平台。核心特点是**代理引擎与 UI 运行在同一进程内**，实现「捕获 → 修改 → 查看 → 持久化」的完整流量处理链路。

**技术栈**：Flutter 3.x / Dart 3.x，`code_forge`（Rust FFI，提供高性能 JS 引擎和文本编辑能力）、`pointycastle`（加密，HTTPS 中间人证书）、`desktop_multi_window`（桌面多窗口）、`get`（状态管理）、`zstandard`/`brotli`（压缩解压）等。

---

## 目录总览

```
lib/main.dart (程序入口)
│
├── lib/network/   ← 代理核心引擎(跨平台共享)
│   ├── bin/          服务器生命周期(ProxyServer/Configuration/EventListener)
│   ├── channel/      网络通道抽象(Netty风格: Channel/Dispatcher/Network)
│   ├── components/   拦截器链 + 各功能配置管理器
│   ├── handle/       请求处理器(HTTP代理/中继/WebSocket/SSE)
│   ├── http/         协议编解码(HTTP1.x/HTTP2/WebSocket/SSE)
│   ├── socks/        SOCKS5 协议实现
│   └── util/         TLS/证书/压缩/系统代理等网络工具
│
├── lib/ui/        ← UI 层(桌面/移动端双套实现)
│   ├── desktop/      桌面端(左侧菜单布局+多窗口)
│   ├── mobile/       移动端(底部导航+抽屉)
│   ├── component/    跨端共享组件(右键菜单/二维码/搜索等)
│   ├── content/      流量详情面板(Body/Headers/WebSocket)
│   ├── toolbox/      工具箱(JSON/XML/编码/正则等)
│   ├── launch/       启动页
│   ├── app_update/   更新检查
│   └── configuration.dart  UI偏好配置(ui_config.json)
│
├── lib/storage/    ← 持久化(历史记录/收藏/HAR)
├── lib/native/     ← 原生桥接(iOS方法通道/Android VPN/PiP)
├── lib/utils/      ← 通用工具(HAR转换/格式化/平台判断等)
└── lib/l10n/       ← 多语言(ARB 生成)
```

---

## 核心模块详解

### 1. `main.dart` — 程序入口
- 初始化 `RustLib`（code_forge 的 Rust FFI，失败时降级不崩溃）
- 根据参数选择启动路径：
  - `multi_window` 参数 → 多窗口模式（`DesktopMultiWindow.initializeFromArguments`）
  - `Platforms.isMobile()` → `MobileHomePage`
  - 桌面端 → `DesktopSupport.initialize` 后进入 `DesktopHomePage`
- `FluentApp` 全局封装：主题（Material3/自定义色）、字体缩放（`textScaler`）、多语言、深浅色模式

### 2. `network` — 代理核心引擎（最重要的部分）

#### `bin/` — 服务器核心
| 文件 | 作用 |
|---|---|
| `server.dart` | **`ProxyServer`**：代理服务器生命周期（start/stop/restart）、绑定端口、**注册并排序拦截器链**、系统代理开关、CA 证书初始化 |
| `configuration.dart` | **`Configuration`**：网络/运行时配置单例（端口 9099、HTTPS 抓包开关、系统代理、外部代理、黑白名单应用、HTTP2 开关），持久化到用户目录 `config.cnf` |
| `listener.dart` | **`EventListener`** 接口 + `CombinedEventListener`：向 UI 广播 `onRequest/onResponse/onMessage` 事件 |

#### `channel/` — 网络管道（Netty 风格的事件驱动模型）
| 文件 | 作用 |
|---|---|
| `channel.dart` | `Channel`（socket 封装）、`ChannelHandler`、`Codec` 编解码器抽象 |
| `channel_context.dart` | `ChannelContext`：一次连接上下文，保存 client/server 通道、当前请求等 |
| `channel_dispatcher.dart` | `ChannelDispatcher`：事件分发器（channelRead、exceptionCaught、channelInactive） |
| `network.dart` | **`Server`/`Network`**：TCP 监听、TLS MITM 握手（`Server.ssl`）、`relay()` 原始字节中继 |
| `host_port.dart` | `HostAndPort` 主机端口值对象 |

#### `components/` — 拦截器模型（核心扩展机制）
`interceptor.dart` 定义 `Interceptor` 抽象类，5 个钩子方法：
- `preConnect(hostAndPort)` — 连接前修改目标地址
- `onRequest(request)` — 请求发出前修改，返回 null 可终止请求
- `execute(request)` — 可短路远程请求，直接返回合成响应
- `onResponse(request, response)` — 响应修改
- `onError(...)` — 错误处理

**拦截器链**（在 `server.dart` 中按 `priority` 排序）：
| 拦截器 | 功能 |
|---|---|
| `hosts.dart` | Hosts 映射（域名→IP） |
| `request_map.dart` | **请求映射**：不请求远程，用本地配置/脚本返回响应 |
| `request_rewrite.dart` | **请求重写**：重定向、替换/增删请求响应报文 |
| `script.dart` | **JS 脚本**：用 JS 处理请求/响应 |
| `request_block.dart` | **请求拦截**：按 URL 阻止请求 |
| `request_breakpoint.dart` | **断点**：请求/响应断点调试 |
| `network_condition.dart` | **弱网模拟**：延迟、限速、丢包 |
| `report_server_interceptor.dart` | 报告服务器（跨端扫码转发流量） |

`manager/` 子目录为各功能的**配置管理器**（读写 JSON 配置文件）：`hosts_manager`、`request_map_manager`、`request_rewrite_manager`、`script_manager`、`request_block_manager`、`request_breakpoint_manager`、`request_crypto_manager`（AES 解密）、`network_condition_manager`、`environment_manager`（环境变量）、`report_server_manager`、`rewrite_rule.dart`（通配符规则匹配）。

`js/` 子目录：`script_engine.dart`（基于 code_forge 的 JS 引擎）、`xhr.dart`/`file.dart`/`md5.dart`（脚本可用的 JS 内置 API 桥接）。

`host_filter.dart`：域名黑白名单过滤（`HostFilter`）。

#### `handle/` — 请求处理器
| 文件 | 作用 |
|---|---|
| `http_proxy_handle.dart` | **`HttpProxyChannelHandler`**：核心路由处理器。证书下载、本地请求、拦截器链执行、重定向、HTTP/1 直连、转发到远程 |
| `relay_handle.dart` | `RelayHandler`：TCP 原始字节双向中继（CONNECT 隧道、非抓包域名直通） |
| `websocket_handle.dart` | WebSocket 升级与帧转发 |
| `sse_handle.dart` | Server-Sent Events 流处理 |

#### `http/` — 协议编解码
| 文件/目录 | 作用 |
|---|---|
| `codec.dart` | `HttpRequestCodec`/`HttpResponseCodec`：HTTP/1.x 报文编解码 |
| `http.dart` | `HttpRequest`/`HttpResponse`/`HttpMessage` 核心模型 |
| `http_client.dart` | 出站 HTTP 客户端（发往目标服务器） |
| `http_headers.dart` | Header 容器 |
| `websocket.dart` | WebSocket 帧编解码 |
| `sse.dart` | SSE 流解析 |
| `parse/` | `http_parser.dart`（报文解析）、`body_reader.dart`（body 读取）、`chunked_decoder.dart`（chunked 解码） |
| `h2/` | **HTTP/2 完整实现**：`h2_codec.dart`、`frame.dart`（帧）、`hpack/`（HPACK 头压缩）、`setting.dart`，支持流式大 body 转发、SSE 按 stream 解码 |
| `constants.dart` / `content_type.dart` | 常量与 Content-Type 工具 |

#### `socks/` — `socks5.dart`：SOCKS5 协议实现（代理服务自身可作为 SOCKS5 入口）

#### `util/` — 网络工具
- `tls.dart` — TLS 中间人握手与证书签发
- `cert/` — X509 证书构建（`x509.dart`、`der.dart`、`pkcs12.dart`、`crts.dart` 等）
- `system_proxy.dart` — 设置/恢复系统代理
- `compress.dart` — gzip/br/deflate 解压
- `crypto.dart` — AES 等加解密（pointycastle）
- `proxy_helper.dart` — 本地响应/证书下载响应等辅助
- `url_pattern.dart` — 通配符 URL 匹配
- 其他：`byte_buf.dart`、`logger.dart`、`cache.dart`、`task_queue.dart`、`random.dart`、`file_read.dart`、`process_info.dart`（进程信息）、`attribute_keys.dart` 等

### 3. `ui` — UI 层（桌面/移动端双套实现，共享组件）

```
ui/
├── configuration.dart    # AppConfiguration：UI 偏好（主题色、字体缩放、M3 开关），存 ui_config.json
├── desktop/              # 桌面端（左侧菜单布局 + 多窗口）
│   ├── desktop.dart          # DesktopHomePage 主框架
│   ├── left_menus/           # navigation/history/favorite
│   ├── request/              # 请求详情/编辑器/域名筛选/重放/时序
│   ├── setting/              # 各功能设置页(hosts/rewrite/map/script/block/弱网等)
│   ├── ssl/                  # 证书安装/HTTPS 抓包设置
│   ├── debug/                # 断点执行器
│   ├── toolbar/ + widgets/   # 工具栏与组件
│   └── window_listener.dart  # 窗口事件监听
├── mobile/               # 移动端（底部导航 + 抽屉，与桌面端功能对等）
├── component/            # 跨端共享组件(右键菜单/多窗口/二维码/搜索/JSON等)
├── content/              # 流量详情(body/headers/panel/web_socket)
├── toolbox/              # 工具箱(json_viewer/xml_viewer/aes/正则/JS运行等)
├── launch/               # 启动页
└── app_update/           # 更新检查
```

### 4. `storage` — 持久化
| 文件 | 作用 |
|---|---|
| `histories.dart` | **`HistoryStorage`**：抓包历史记录（存 `histories.json`），`HistoryTask` 定期批量落盘；支持 HAR 导出/导入、分享 |
| `favorites.dart` | **收藏**：收藏的请求/响应，持久化前会**裁剪 WebSocket/SSE 帧数量和 payload 大小** |
| `local_storage.dart` | 本地存储抽象 |
| `path.dart` | `Paths.getPath()` 路径解析 |
| `shared_preference_keys.dart` | SharedPreferences 键名常量 |

### 5. `utils` — 通用工具
- `har.dart` — HAR 格式转换
- `desktop_support.dart` / `desktop_tray.dart` — 桌面支持与系统托盘
- `platform.dart` — 平台判断（`Platforms`）
- `curl.dart` — 请求转 curl 命令
- `export_request.dart` — 请求导出
- `navigator.dart` — 全局导航
- 格式化器：`html_formatter`、`xml_formatter`、`css_formatter`、`js_formatter`（高亮）
- 其他：`aes.dart`、`crypto_body_decoder.dart`、`keyword_highlight.dart`、`text_diff.dart`、`quick_share.dart`、`ip.dart`、`font.dart`、`lang.dart`、`listenable_list.dart`、`num.dart`、`task.dart`、`files.dart`、`python.dart`

### 6. `native` — 原生桥接
| 文件 | 作用 |
|---|---|
| `native_method.dart` | iOS 方法通道 `com.proxypin/method`（本地网络权限、证书信任检查） |
| `vpn.dart` | Android VPN 接口 |
| `pip.dart` | Android 画中画 |
| `app_lifecycle.dart` | 应用生命周期 |
| `installed_apps.dart` | 已安装应用列表（Android 白名单用） |
| `process_info.dart` | 进程信息 |

### 7. `l10n` — 多语言
由 `l10n.yaml` 配置，从 ARB 文件生成 `AppLocalizations`；`l10n_errors.txt` 跟踪未翻译键。

---

## 核心数据流（一次完整请求的处理链路）

```
客户端(浏览器/App)
    │  ① TCP 连接 + HTTP 请求
    ▼
Server (channel/network.dart)
    │  TCP 监听、接受连接、TLS MITM 握手
    ▼
ChannelDispatcher (channel/channel_dispatcher.dart)
    │  ② 字节流到达 → 分发给 ChannelHandler
    ▼
HttpProxyChannelHandler (handle/http_proxy_handle.dart)
    │  ③ HttpRequestCodec 解码出 HttpRequest
    │  ④ 分流判断：
    │     - 证书下载请求(http://proxy.pin/ssl)? → 直接返回证书
    │     - 请求本服务? → 本地响应
    │     - 域名被 HostFilter 过滤? → 原始字节中继(不抓包)
    │     - 否则 → 进入拦截器链
    ▼
拦截器链 (components/, 按 priority 排序)
    │  ⑤ onRequest:  逐个执行，可修改请求；返回 null 则终止请求
    │  ⑥ execute:    某个拦截器可短路(如请求映射)，直接返回合成响应
    ▼
远程服务器
    │  HttpProxyChannelHandler 通过 http_client 转发(HTTP/1 或 HTTP/2)
    │  ⑦ 收到响应
    ▼
拦截器链
    │  ⑧ onResponse: 逐个执行，可修改响应(重写/脚本/解密)
    ▼
HttpResponseCodec 编码 → 写回客户端
    │  ⑨
    ▼
客户端收到响应

※ 整个过程每个阶段都通过 EventListener 广播事件 → UI 实时刷新历史列表/详情面板
```

---

## 平台目录与测试
- **平台壳**：`android`、`ios`、`macos`、`windows`、`linux` — 标准 Flutter 平台工程；原生插件在 `MainActivity.kt`（Android）与 `MethodHandler.swift`（iOS）注册；`build.sh` 为 deb 打包脚本
- **测试**（`test`）：协议测试（`http_test`、`websocket_persistence_test`、`sse_chunked_test`、`websocket_decoder_test`）、证书测试（`cert_test`、`pk12_test`、`x509_test`）、规则测试（`url_test`、`request_rewrite_interceptor_test`）、UI 组件测试（`context_menu_test`、`search_controller_test` 等）、JS 引擎测试（`js_test`）、`requests_test.py`（Python 端到端测试）
- **资源**：`certs`（CA 证书）、`fetch.js`（脚本环境注入）

---

## 设计要点总结
1. **拦截器模式是灵魂**：所有流量变更功能（重写/映射/脚本/阻断/断点/弱网）都通过 `Interceptor` 钩子实现，新增功能只需实现接口并注册，无需改动处理器内部
2. **Netty 式事件驱动**：`Channel → ChannelDispatcher → ChannelHandler → Codec` 的管道模型，支持原始字节中继与协议级处理并存
3. **协议覆盖面广**：HTTP/1.x、HTTP/2（含 HPACK）、WebSocket、SSE、SOCKS5、TLS MITM 全部自研实现
4. **桌面/移动端对称**：共享 `lib/network/**` 代理逻辑，UI 按平台分别实现保持功能对等
5. **配置外置**：运行时配置（`config.cnf`、`request_rewrite.json` 等）存于用户目录而非仓库，UI 偏好与代理配置分离（`ui_config.json`）