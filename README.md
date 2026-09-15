# ProxyPin

English | [中文](README_CN.md)
## Open source free traffic capture HTTP(S)，Support Windows、Mac、Android、IOS、Linux Full platform system

You can use it to intercept, inspect & rewrite HTTP(S) traffic, Support capturing Flutter app traffic, ProxyPin is based on Flutter develop, and the UI is beautiful
and easy to use.

## Features
* Mobile scan code connection: no need to manually configure WiFi proxy, including configuration synchronization. All terminals can scan codes to connect and forward traffic to each other.
* Domain name filtering: Only intercept the traffic you need, and do not intercept other traffic to avoid interference with other applications.
* Search: Search requests according to keywords, response types and other conditions
* Script: Support writing JavaScript scripts to process requests or responses.
* Request Rewrite: Support redirection, support replacement of request or response message, and can also modify request or response according to the increase.
* Request Mapping: Do not request remote services, use local configuration or scripts for response
* Request Decryption: Configure AES decryption key to automatically decrypt HTTP message body
* Request Blocking: Support blocking requests according to URL, and do not send requests to the server.
* History: Automatically save the captured traffic data for easy backtracking and viewing. Support HAR format export and import.
* Others: Favorites, toolbox, common encoding tools, as well as QR codes, regular expressions, etc.

**Mac will prompt untrusted developers when first opened, you need to go to System Preferences-Security & Privacy-Allow any source.**

## Sponsors

If ProxyPin is helpful to you, you are welcome to support us in the following ways to help the project develop in the long term:

* [Buy Me A Coffee](https://buymeacoffee.com/proxypin)
* [AFDIAN](https://afdian.com/a/proxypin)
* Submit feedback and suggestions to help us improve
* Contribute code or documentation to the project

**Your support will be used for project maintenance, feature development, and user experience optimization. Thank you very much!**

## Downloads

Github Releases: https://github.com/wanghongenpin/proxypin/releases

iOS App Store：https://apps.apple.com/app/proxypin/id6450932949

Android Google Play：https://play.google.com/store/apps/details?id=com.network.proxy

TG: https://t.me/proxypin_en

**We will continue to improve the features and experience, as well as optimize the UI.**

<img alt="image"  width="580px" height="420px"  src="https://github.com/user-attachments/assets/6c1345ab-c95c-415d-ac59-470c764b59a2">.<img alt="image"  height="500px" src="https://github.com/user-attachments/assets/3c5572b0-a9e5-497c-8b42-f935e836c164">


## Build from source

### Requirements

* Flutter SDK (see the `environment.sdk` constraint in `pubspec.yaml`)
* Only needed for packaging installers: `dart pub global activate flutter_distributor`
* macOS DMG packaging additionally needs `appdmg` (`npm install -g appdmg`)

### Get dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run -d macos      # or: windows | linux | android | ios
```

The proxy is started from the UI, there is no separate background daemon.

### Package

Release jobs are declared in `distribute_options.yaml`; artifacts are written to `dist/<version>/`.
Prefer the `release` command so the declared build mode and artifact name are applied:

```bash
# run a single job
flutter_distributor release --name release --jobs macos-dmg

# run every job of the "release" definition
flutter_distributor release --name release
```

The `package` command builds one platform/target ad hoc. It does **not** read the `build_args`
and `artifact_name` settings from `distribute_options.yaml`, so pass them explicitly. Each
platform must be packaged on its own host OS:

```bash
# on macOS:
flutter_distributor package --platform macos --targets dmg \
  --artifact-name 'ProxyPin-{{build_name}}-macos.{{ext}}'

# on Windows (running these on macOS/Linux only prints a warning and produces nothing):
flutter_distributor package --platform windows --targets exe
flutter_distributor package --platform windows --targets msix
flutter_distributor package --platform windows --targets zip
```

Platform helpers:

```bash
# Linux: .deb package (run after `flutter build linux --release`)
bash linux/build.sh

# Windows: .zip + Inno Setup installer
powershell -ExecutionPolicy Bypass -File windows/build.ps1
```

Notes:

* Host platform matters: each target must be packaged on its own OS. Packaging a Windows target on macOS prints
  `Warning: AppBuilderWindows is not supported on the current platform` and skips the job. iOS builds need macOS + Xcode.
* `flutter_distributor release --name release` runs every job in order and only warns on jobs the current OS cannot build,
  so it is safe to run anywhere, but each artifact still has to be produced on its own OS.
* Artifact naming comes from `artifact_name` in `distribute_options.yaml`. Available template variables: `{{name}}` `{{build_name}}` `{{build_number}}` `{{version}}` `{{build_mode}}` `{{platform}}` `{{ext}}`.
* The macOS DMG window layout comes from `macos/packaging/dmg/make_config.yaml`.
* macOS/Windows artifacts are not code signed. On macOS the first launch needs System Settings → Privacy & Security → "Open Anyway".
* iOS and Android use the standard `flutter build ipa` / `flutter build apk --release` flow with the platform settings under `ios/` and `android/`.


### Powered by
[![JetBrains logo.](https://resources.jetbrains.com/storage/products/company/brand/logos/jetbrains.svg)](https://jb.gg/OpenSource)