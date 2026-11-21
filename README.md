# HiFlutter

跨项目共用的 Flutter 效率库（Dart `^3.14.0` / Flutter `>=3.50.0`，一等平台为 Android 与 iOS），采用 Dart pub workspace 多包架构，按“契约包 + 适配包”的包家族组织，底层不绑定状态管理，提供面向消费项目的三种无侵入集成模式与统一门禁工具链。

详细规则、架构决策与工程规范请查阅 [文档索引](docs/README.md) 与 [领域术语表](GLOSSARY.md)。

## 包一览

仓库根目录为 pub workspace，所有可发布包统一版本号 `0.1.0`；另含不发布的示例 App `apps/showcase`。

| 家族 / 角色 | 包名 | 平台 | 核心能力与预置依赖 | 纳入伞包 `hiflutter` |
| --- | --- | --- | --- | --- |
| 伞包 | `hiflutter` | Flutter | 重新导出常用契约包与默认非厂商适配包，零第三方类型外露、零自动初始化 | 入口包本身 |
| 工具 | `hiflutter_tool` | 纯 Dart CLI | `hiflutter` 命令：在源码 / 锁定 / 发布三种集成模式间切换与发布检查 | 否（全局安装） |
| 集成骨架 | `hiflutter_riverpod` | Flutter | 可选应用骨架：12 个契约 Provider、`HiPaginationNotifier` 与 `HiRiverpodBootstrap`（`flutter_riverpod`） | 可选 |
| `base` | `hiflutter_base` | 纯 Dart | 密封 `HiError` 模型、路由脱敏日志 `HiLogger`/`HiLog`、`HiAnalytics`/`HiCrashReporter`/`HiConsent`、`HiConvert`、`HiMapPick` | ✓ |
| `base` | `hiflutter_base_log_file` | Flutter | `HiFileLogSink` 按天轮转日志文件输出端（`path_provider`） | ✓ |
| `core` | `hiflutter_core` | Flutter | `HiErrorCapture`、`HiSafeValueNotifier`、`HiFormat`、`HiLinkDetector`、`HiColor`/上下文扩展、`HiDeviceInfoSource` | ✓ |
| `core` | `hiflutter_core_device` | Flutter | `HiPlatformDeviceInfoSource` 设备与安装包信息（`device_info_plus`、`package_info_plus`） | ✓ |
| `net` | `hiflutter_net` | 纯 Dart | `HiHttpClient`、`HiTransport`、`HiEnvelope` 解包、`HiPageResult`、`HiConnectivity` 契约 | ✓ |
| `net` | `hiflutter_net_dio` | 纯 Dart | `HiDioTransport`（`dio`）并归一化 `DioException` 为 `HiError` | ✓ |
| `net` | `hiflutter_net_connectivity` | Flutter | `HiPlusConnectivity` 网络连通状态流（`connectivity_plus`） | 可选 |
| `nav` | `hiflutter_nav` | Flutter | 强类型 `HiRoute`、`HiRouteTable`、`HiDeepLinkGuard`、`HiNavigator`、`HiLinkOpener` | ✓ |
| `nav` | `hiflutter_nav_go_router` | Flutter | `HiGoRouterNavigator`（`go_router`） | ✓ |
| `nav` | `hiflutter_nav_url_launcher` | Flutter | `HiUrlLauncherLinkOpener`（`url_launcher`） | ✓ |
| `store` | `hiflutter_store` | 纯 Dart | `HiKeyValueStore`（拒存凭据键）、`HiSecureStore`、`HiFileStore`（防路径穿越）及内存实现 | ✓ |
| `store` | `hiflutter_store_prefs` | Flutter | `HiPrefsKeyValueBackend`（`shared_preferences`） | ✓ |
| `store` | `hiflutter_store_secure` | Flutter | `HiSecureStorageBackend`（`flutter_secure_storage`） | ✓ |
| `store` | `hiflutter_store_file` | Flutter | `HiAppFileBackend`（`path_provider` + `dart:io`） | ✓ |
| `suite` | `hiflutter_suite` | Flutter | Material 3 组件：中英本地化、状态视图、分页控制器/列表、轻提示、对话框、列表行、按钮、搜索框（`material_ui`、`intl`） | ✓ |
| `suite` | `hiflutter_suite_cached_image` | Flutter | `HiCachedImage` 与 `HiImageViewer`（`cached_network_image`） | 可选 |
| `suite` | `hiflutter_suite_webview` | Flutter | `HiWebViewPage` 网页容器与外链转交（`webview_flutter`） | 可选 |
| 示例 App | `apps/showcase` | Flutter | 演示全家族及全部可选包的本地参考应用（`publish_to: none`） | 不发布 |

## 消费项目快速上手（三种集成模式）

消费项目与 `HiFlutter` 位于同一父目录下时，只需在自身 `pubspec.yaml` 中声明一份正常版本依赖，通过 `pubspec_overrides.yaml` 切换来源：

```yaml
dependencies:
  hiflutter: ^0.1.0
  # 按需选装可选包：
  # hiflutter_riverpod: ^0.1.0
```

全局安装 `hiflutter` CLI（与具体消费项目所处模式解耦）：

```bash
dart pub global activate --source path /path/to/HiFlutter/packages/hiflutter_tool
```

在消费项目根目录执行：

```bash
# 1. 源码模式：开发联调，自动计算传递闭包并指向同级 ../HiFlutter
hiflutter mode source
flutter pub get

# 2. 锁定模式：发版分支锁定到某次 HiFlutter 发版 tag（pub.dev 尚未正式发布期间使用）
hiflutter mode pin v0.1.0
flutter pub get

# 3. 发布模式：清除工具托管的 HiFlutter 覆盖条目，回退到 pub.dev 解析
hiflutter mode hosted
flutter pub get

# 构建与发布门禁（源码模式下运行 --release 会以非零码拦截）
hiflutter check
hiflutter check --release
```

更多目录覆盖选项（`--hiflutter-dir`、`HIFLUTTER_DIR`、`--git-url`）与可直接引用的接入规则见 [集成模式与接入规范](docs/engineering/integration.md)。

## 最小使用示例

不使用状态管理绑定时，在组合根手动装配并安装日志与全局错误捕获：

```dart
import 'package:flutter/widgets.dart';
import 'package:hiflutter/hiflutter.dart';

Future<void> main() async {
  // 1. 全局日志仅允许安装一次，未安装时所有日志静默跳过。
  final logger = HiLogger([const HiLogRoute(HiConsoleLogSink())]);
  HiLog.install(logger);

  // 2. 隐私同意门控：用户明确同意前不外发上报，unknown 视为未同意。
  final consent = HiConsent();
  final reporter = HiConsentGatedCrashReporter(
    const HiNoOpCrashReporter(),
    consent: consent,
  );

  // 3. 接管 Flutter 框架与平台错误，并在守护 Zone 内启动应用。
  final capture = HiErrorCapture.install(reporter: reporter);

  // 4. 在组合根构造网络客户端与存储实例后按需注入。
  final client = HiHttpClient(
    transport: HiDioTransport(),
    baseUrl: Uri.parse('https://api.example.com/v1/'),
    envelope: const HiEnvelope(),
  );
  final kvStore = HiKeyValueStore(HiPrefsKeyValueBackend());
  await kvStore.setString('theme', 'system');

  capture.runGuarded(() {
    HiLog.info(() => 'App started with client=$client', module: 'boot');
    runApp(const SizedBox.shrink());
  });
}
```

若使用可选的 `hiflutter_riverpod` 应用骨架，可直接调用 `HiRiverpodBootstrap.run` 按固定顺序完成日志安装、错误捕获、绑定初始化、`ProviderScope` 覆盖装配与 `runApp`，参见 `apps/showcase/lib/main.dart`。

## 仓库检查命令

```bash
# 运行全部 8 个默认检查阶段（format, analyze, test, deps, terms, versions, publish, e2e）
dart run tool/check.dart

# 额外执行 apps/showcase 的 Android APK 与 iOS Simulator 冒烟构建（macOS）
dart run tool/check.dart --build

# 按阶段单独运行
dart run tool/check.dart --only format,deps,terms

# 仅报告超出当前 caret 约束的可破坏性第三方依赖更新
dart run tool/deps_report.dart
```
