# 第三方依赖准入、版本基线与更新流程

本文件规定 HiFlutter 引入与维护第三方依赖的准入检查、版本约束与更新处理流程。日常版本跟踪由 `tool/deps_report.dart` 与每周 CI 工作流 `.github/workflows/deps.yml` 执行。

## 新库准入清单

在任何 HiFlutter 包中新增第三方依赖前，必须逐项审查以下六个维度并在包 `pubspec.yaml`、PR 或 Issue 中说明依据：

1. **许可证兼容性**：须为 MIT、BSD-2/3-Clause、Apache-2.0 等宽松开源许可证；排除 GPL/AGPL 等传染性许可证。
2. **维护状态**：近一年内有活跃提交或稳定发布记录，兼容当前 Dart SDK（`^3.14.0`）与 Flutter（`>=3.50.0`），已完备空安全支持。
3. **发布者可信度**：优先选用 `dart.dev`、`flutter.dev`、`fluttercommunity.dev` 等官方或受信任已验证发布者（verified publisher）。
4. **平台支持**：一等支持 Android 与 iOS；避免强绑定无法通过编译的老旧平台插件或已停止维护的原生桥接。
5. **权限与隐私影响**：评估是否自动向 `AndroidManifest.xml` 或 `Info.plist` 注入敏感权限（定位、蓝牙、相机、后台保活等）以及是否触发隐私合规/商店审核说明。若会带入敏感权限或较重原生代码，**不得纳入伞包 `hiflutter`**，应作为独立可选适配包。
6. **传递依赖**：检查传递依赖树规模与常见冲突风险（如 `http`、`intl`、Kotlin/Gradle 插件、SwiftPM/CocoaPods 版本），优先选择依赖浅、社区共用基线一致的包。

## 预置第三方依赖版本基线

下表列出当前（基线核对日期：2026-11-21）各包直接依赖的第三方库及其约束原因，所有约束一律采用 caret（`^`）范围：

| 类别 / 所在包 | 依赖包名 | 当前约束 | 约束原因与角色 |
| --- | --- | --- | --- |
| `hiflutter_base_log_file` | `path_provider` | `^2.1.6` | 获取应用支持目录（`ApplicationSupportDirectory`）存放可导出日志 |
| `hiflutter_core_device` | `device_info_plus` | `^13.3.0` | 读取 Android / iOS 设备型号与系统版本以实现 `HiDeviceInfoSource` |
| `hiflutter_core_device` | `package_info_plus` | `^10.2.2` | 读取 App 名称、包名、版本号与构建号，拼装 User-Agent |
| `hiflutter_net_dio` | `dio` | `^5.11.1` | 实现纯 Dart HTTP 传输契约 `HiTransport`，并收敛 `DioException` |
| `hiflutter_net_connectivity` | `connectivity_plus` | `^7.3.2` | 可选适配包，监听系统网络接口变更实现 `HiConnectivity` |
| `hiflutter_nav_go_router` | `go_router` | `^18.1.4` | 根据 `HiRouteTable` 生成声明式路由配置实现 `HiNavigator` |
| `hiflutter_nav_url_launcher` | `url_launcher` | `^6.3.3` | 实现外链打开契约 `HiLinkOpener` |
| `hiflutter_store_prefs` | `shared_preferences` | `^2.5.6` | 实现明文键值存储后端 `HiPrefsKeyValueBackend` |
| `hiflutter_store_secure` | `flutter_secure_storage` | `^11.2.0` | 基于 iOS Keychain 与 Android Keystore 实现 `HiSecureStorageBackend` |
| `hiflutter_store_file` | `path_provider` | `^2.1.6` | 定位应用私有文档/支持目录配合 `dart:io` 实现 `HiAppFileBackend` |
| `hiflutter_suite` | `intl` | `^0.20.2` | 配合 `flutter_localizations` 与 `gen-l10n` 生成中英组件本地化文案 |
| `hiflutter_suite` | `material_ui` | `^1.11.1` | 提供从 Flutter 3.50+ 剥离的 Material 3 组件（替代已弃用的 `flutter/material.dart`） |
| `hiflutter_suite_cached_image` | `cached_network_image` | `^4.0.7` | 可选适配包，实现带磁盘缓存的网络图片 `HiCachedImage` 与 `HiImageViewer` |
| `hiflutter_suite_cached_image` | `material_ui` | `^1.11.1` | 为图片预览与加载占位提供 Material 3 基础主题与控件 |
| `hiflutter_suite_webview` | `webview_flutter` | `^4.14.1` | 可选适配包，提供内嵌网页容器页面 `HiWebViewPage` |
| `hiflutter_suite_webview` | `material_ui` | `^1.11.1` | 为网页页面导航栏、进度条与重试视图提供 Material 3 控件 |
| `hiflutter_riverpod` | `flutter_riverpod` | `^3.5.0` | 可选应用骨架，提供契约 Provider、分页 Notifier 与 `ProviderScope` 启动引导 |
| `hiflutter_tool` | `args` | `^2.7.0` | 解析 `hiflutter mode` 与 `hiflutter check` 命令行参数 |
| `hiflutter_tool` | `path` | `^1.9.1` | 跨平台规范化与 POSIX 相对路径计算 |
| `hiflutter_tool` | `yaml` | `^3.1.3` | 只读解析消费者与 HiFlutter 仓库的 `pubspec.yaml` / `pubspec_overrides.yaml` / `pubspec.lock` |
| `hiflutter_tool` | `yaml_edit` | `^2.2.4` | 无损编辑 YAML 节点，保留用户原有注释与自有覆盖 |
| 根工作区脚本（`dev_dependencies`） | `pub_semver` | `^2.2.1` | 在 `tool/bump_version.dart` 与 `tool/deps_report.dart` 中严格解析 SemVer 与 caret 范围 |

开发测试、静态分析与平台接口假实现基线（`dev_dependencies`）：

- 静态分析：`lints: ^6.1.0`（纯 Dart 包与根工作区）、`flutter_lints: ^6.0.0`（Flutter 包与 `apps/showcase`）
- 测试框架：`test: ^1.26.0`、`flutter_test`（Flutter SDK）
- 平台接口假实现测试底座：`plugin_platform_interface: ^2.1.8`、`path_provider_platform_interface: ^2.1.2`、`device_info_plus_platform_interface: ^8.1.0`、`package_info_plus_platform_interface: ^4.1.0`、`connectivity_plus_platform_interface: ^2.1.0`、`url_launcher_platform_interface: ^2.3.2`、`shared_preferences_platform_interface: ^2.4.1`、`flutter_secure_storage_platform_interface: ^2.1.1`、`webview_flutter_platform_interface: ^2.15.1`

> 注：按 `tool/src/package_rules.dart` 约定，纯契约包 `hiflutter_base`、`hiflutter_core`、`hiflutter_net`、`hiflutter_nav`、`hiflutter_store` 可按需使用 Dart 官方 `meta` 与 `collection`，不引入其余任何第三方运行时库。

## 兼容更新与消费项目冻结

- 所有直接第三方依赖一律使用 caret 约束（`^x.y.z`）。
- 消费项目执行 `flutter pub upgrade` 时，会自动在 caret 范围内获取兼容更新（例如 `1.x` 内的 minor/patch 升级或 `0.y.z` 内的 patch 升级），无需等待 HiFlutter 发版，也不会越过主版本引入破坏性 API 变更。
- 若消费项目不执行升级，其自身仓库提交的 `pubspec.lock` 会完整冻结所有解析版本，确保已发版应用的构建可完全复现。

## 破坏性更新报告与处理流程

当第三方库发布越过当前 caret 约束的新版本时，必须显式审查与人工决策，**绝不自动修改约束悄悄升级**。完整流程如下：

1. **检查与生成报告**：
   - 本地可随时运行：
     ```bash
     dart run tool/deps_report.dart [--root <dir>] [--json | --markdown]
     ```
   - 脚本底层运行 `flutter pub outdated --json --no-prereleases`（纯 Dart 工作区则运行 `dart pub outdated --json --no-prereleases`），对比全部工作区包（含根 `pubspec.yaml`）的直接 `dependencies` 与 `dev_dependencies`：
     - 退出码 `0`：没有可做的破坏性更新；
     - 退出码 `2`：至少存在一个破坏性更新，输出所在包、依赖名、当前约束、最新稳定版与 pub.dev changelog 链接；
     - 退出码 `1`：执行 `pub outdated` 失败（由脚本错误导致）；
     - 退出码 `64`：参数使用错误。
2. **每周定时提示 Issue**：
   - `.github/workflows/deps.yml` 每周一 UTC 01:00（以及支持手动 `workflow_dispatch`）运行 `dart run tool/deps_report.dart --markdown`。
   - 当退出码为 `2` 时，工作流通过 `gh` 在跟踪器上创建或原地更新唯一一个带 `deps-breaking` 标签、固定标题为 `第三方依赖有可做的破坏性更新` 的提示 Issue，正文即为报告表格；无破坏性更新时不打扰跟踪器。
3. **智能体评估与维护者决策**：
   - 收到带 `deps-breaking` 的更新报告后，智能体先阅读目标库的 changelog，评估该破坏性更新对 HiFlutter 适配包实现、行为语义、最低 Dart/Flutter SDK 要求以及传递依赖的影响，形成升级/暂缓建议回复在 Issue 上。
   - 维护者审阅评估结论后拍板是否升级。
4. **落地升级与迁移说明**：
   - 确认升级后，更新对应包 `pubspec.yaml` 中的 caret 约束与受影响适配代码；
   - 在改动包的 `CHANGELOG.md` 顶部 `## Unreleased` 小节写明破坏性变更与消费项目迁移要点；
   - 运行 `dart run tool/check.dart`（涉及原生配置或宿主构建时追加 `--build`）确认全部阶段通过后再关闭或更新对应跟踪任务。
