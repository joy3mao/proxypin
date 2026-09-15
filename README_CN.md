# ProxyPin

[English](README.md) | 中文
## 开源免费抓包工具，支持Windows、Mac、Android、IOS、Linux 全平台系统

您可以使用它来拦截、检查和重写HTTP（S）流量，支持Flutter应用抓包，ProxyPin基于Flutter开发，UI美观易用。

## 核心特性

* 手机扫码连接: 不用手动配置Wifi代理，包括配置同步。所有终端都可以互相扫码连接转发流量。
* 域名过滤: 只拦截您所需要的流量，不拦截其他流量，避免干扰其他应用。
* 搜索：根据关键词响应类型多种条件搜索请求
* 脚本: 支持编写JavaScript脚本来处理请求或响应。
* 请求重写: 支持重定向，支持替换请求或响应报文，也可以根据增则修改请求或或响应。
* 请求映射: 不请求远程服务，使用本地配置或脚本进行响应
* 请求解密: 配置AES解密密钥，自动解密HTTP消息体
* 请求屏蔽: 支持根据URL屏蔽请求，不让请求发送到服务器。
* 历史记录：自动保存抓包的流量数据，方便回溯查看。支持HAR格式导出与导入。
* 其他：收藏、工具箱、常用编码工具、以及二维码、正则等

**Mac首次打开会提示不受信任开发者，需要到系统偏好设置-安全性与隐私-允许任何来源。**

## 赞助 

如果您觉得ProxyPin对您有帮助，欢迎通过以下方式支持我们，帮助项目长期发展：

* [爱发电赞助](https://afdian.com/a/proxypin)
* [Buy Me A Coffee](https://buymeacoffee.com/proxypin)
* 提交反馈和建议，帮助我们改进
* 为项目贡献代码或文档

**您的支持将用于项目的维护、功能开发和用户体验优化，非常感谢！**    

## 下载地址

国内下载： https://gitee.com/wanghongenpin/proxypin/releases

iOS App Store： https://apps.apple.com/app/proxypin/id6450932949      

Android Google Play：https://play.google.com/store/apps/details?id=com.network.proxy

TG: https://t.me/proxypin_tg

**接下来会持续完善功能和体验，UI优化。**

<img alt="image"  width="580px" height="420px"  src="https://github.com/user-attachments/assets/80f30d64-f2b5-473c-98f5-bae50b309278">.<img alt="image"  height="500px" src="https://github.com/user-attachments/assets/3c5572b0-a9e5-497c-8b42-f935e836c164">

## 从源码构建

### 环境要求

* Flutter SDK（版本约束见 `pubspec.yaml` 中的 `environment.sdk`）
* 仅打包安装包时需要：`dart pub global activate flutter_distributor`
* macOS 打包 DMG 还需要 `appdmg`（`npm install -g appdmg`）

### 获取依赖

```bash
flutter pub get
```

### 运行

```bash
flutter run -d macos      # 也可用 windows | linux | android | ios
```

代理服务由 UI 启动，没有独立的后台进程。

### 打包

打包任务在 `distribute_options.yaml` 中定义，产物输出到 `dist/<版本>/`。
推荐用 `release` 命令，这样配置里声明的构建模式与产物名才会生效：

```bash
# 执行单个任务
flutter_distributor release --name release --jobs macos-dmg

# 执行 "release" 中定义的全部任务
flutter_distributor release --name release
```

`package` 命令用于临时打包单个平台/目标，它**不会**读取 `distribute_options.yaml` 里的
`build_args` 与 `artifact_name`，需要显式传入。命令需在目标平台上执行：

```bash
# 在 macOS 上：
flutter_distributor package --platform macos --targets dmg \
  --artifact-name 'ProxyPin-{{build_name}}-macos.{{ext}}'

# 在 Windows 上（macOS/Linux 上执行只会打印 Warning 且不产生产物）：
flutter_distributor package --platform windows --targets exe
flutter_distributor package --platform windows --targets msix
flutter_distributor package --platform windows --targets zip
```

各平台辅助脚本：

```bash
# Linux：生成 .deb 包（需先执行 flutter build linux --release）
bash linux/build.sh

# Windows：生成 .zip 与 Inno Setup 安装包
powershell -ExecutionPolicy Bypass -File windows/build.ps1
```

说明：

* 平台限制：每个平台的包必须在对应系统上构建。在 macOS 上打包 Windows 目标会提示
  `Warning: AppBuilderWindows is not supported on the current platform` 并跳过该任务；
  iOS 需要在 macOS + Xcode 上构建。
* `flutter_distributor release --name release` 会依次执行全部任务，在不支持的任务上同样只警告并跳过，
  所以可跨平台安全的运行，但需在对应系统上执行才能得到产物。
* 产物名由 `distribute_options.yaml` 的 `artifact_name` 决定，可用变量：`{{name}}` `{{build_name}}` `{{build_number}}` `{{version}}` `{{build_mode}}` `{{platform}}` `{{ext}}`。
* macOS DMG 的窗口布局由 `macos/packaging/dmg/make_config.yaml` 定义。
* macOS/Windows 产物未做代码签名，macOS 首次打开需到「系统偏好设置 → 安全性与隐私」中允许打开。
* iOS、Android 使用标准的 `flutter build ipa` / `flutter build apk --release` 流程，工程配置位于 `ios/`、`android/`。

