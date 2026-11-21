# 包家族、职责与依赖方向

HiFlutter 采用 Dart pub workspace 管理多包架构（详见 [ADR-0004](../adr/0004-multi-package-workspace.md)），防止消费项目未使用的第三方插件原生代码与系统权限被强制带入安装包。

## 五种包角色

在依赖图检查脚本 `tool/src/package_rules.dart` 中，所有 20 个可发布包分为五类角色（对应 `PackageRole` 枚举）：

| 角色 | 枚举值 | 职责与边界 |
| --- | --- | --- |
| **契约包** | `PackageRole.contract` | 只定义 HiFlutter 自有类型与接口，不依赖任何第三方库（除全契约通用的官方 `meta`、`collection` 与 Flutter SDK 之外；`hiflutter_suite` 例外允许使用 `intl`、`flutter_localizations` 与 `material_ui`）。 |
| **适配包** | `PackageRole.adapter` | 用具体的第三方库或原生插件实现契约包接口；第三方类型与异常不得越过它暴露给调用方公开接口。 |
| **集成包** | `PackageRole.integration` | 可选应用骨架 `hiflutter_riverpod`（[ADR-0002](../adr/0002-state-management-agnostic-core.md)），为各契约提供 Riverpod Provider、分页 Notifier 与启动骨架。 |
| **伞包** | `PackageRole.umbrella` | 便捷入口 `hiflutter`，仅重新导出伞内成员的自有公开 API，不导出第三方类型，不执行任何自动初始化。 |
| **工具包** | `PackageRole.tool` | 独立 CLI 包 `hiflutter_tool`（可执行名 `hiflutter`），不依赖任何 HiFlutter 运行时包，仅供消费项目全局安装。 |

## 包家族与允许依赖方向表

以下依赖规则由 `dart run tool/check.dart` 的 `deps` 阶段（`tool/src/stages/deps_stage.dart`）逐条校验并检测环；新增任何包或内部依赖必须同步更新 `tool/src/package_rules.dart`。

| 家族 | 包名 | 角色 | 允许依赖的 HiFlutter 内部包 | Flutter SDK / 特批第三方 | 纳入伞包 |
| --- | --- | --- | --- | --- | --- |
| `base` | `hiflutter_base` | 契约包（纯 Dart） | 无 | 否 | ✓ |
| `base` | `hiflutter_base_log_file` | 适配包（Flutter） | `hiflutter_base` | `path_provider` | ✓ |
| `core` | `hiflutter_core` | 契约包（Flutter） | `hiflutter_base` | Flutter SDK | ✓ |
| `core` | `hiflutter_core_device` | 适配包（Flutter） | `hiflutter_core`、`hiflutter_base` | `device_info_plus`、`package_info_plus` | ✓ |
| `net` | `hiflutter_net` | 契约包（纯 Dart） | `hiflutter_base` | 否 | ✓ |
| `net` | `hiflutter_net_dio` | 适配包（纯 Dart） | `hiflutter_net`、`hiflutter_base` | `dio` | ✓ |
| `net` | `hiflutter_net_connectivity` | 适配包（Flutter） | `hiflutter_net`、`hiflutter_base` | `connectivity_plus` | 可选 |
| `nav` | `hiflutter_nav` | 契约包（Flutter） | `hiflutter_base` | Flutter SDK | ✓ |
| `nav` | `hiflutter_nav_go_router` | 适配包（Flutter） | `hiflutter_nav`、`hiflutter_base` | `go_router` | ✓ |
| `nav` | `hiflutter_nav_url_launcher` | 适配包（Flutter） | `hiflutter_nav`、`hiflutter_base` | `url_launcher` | ✓ |
| `store` | `hiflutter_store` | 契约包（纯 Dart） | `hiflutter_base` | 否 | ✓ |
| `store` | `hiflutter_store_prefs` | 适配包（Flutter） | `hiflutter_store`、`hiflutter_base` | `shared_preferences` | ✓ |
| `store` | `hiflutter_store_secure` | 适配包（Flutter） | `hiflutter_store`、`hiflutter_base` | `flutter_secure_storage` | ✓ |
| `store` | `hiflutter_store_file` | 适配包（Flutter） | `hiflutter_store`、`hiflutter_base` | `path_provider` + `dart:io` | ✓ |
| `suite` | `hiflutter_suite` | 契约包（Flutter） | `hiflutter_base`、`hiflutter_core` | Flutter SDK、`flutter_localizations`、`intl`、`material_ui` | ✓ |
| `suite` | `hiflutter_suite_cached_image` | 适配包（Flutter） | `hiflutter_suite`、`hiflutter_base` | `cached_network_image`、`material_ui` | 可选 |
| `suite` | `hiflutter_suite_webview` | 适配包（Flutter） | `hiflutter_suite`、`hiflutter_base`、`hiflutter_nav` | `webview_flutter`、`material_ui` | 可选 |
| 集成 | `hiflutter_riverpod` | 集成包（Flutter） | 全部 6 个契约包（`hiflutter_base`、`hiflutter_core`、`hiflutter_net`、`hiflutter_nav`、`hiflutter_store`、`hiflutter_suite`） | `flutter_riverpod` | 可选 |
| 伞包 | `hiflutter` | 伞包（Flutter） | 下述 14 个伞包成员 | Flutter SDK | 入口本身 |
| 工具 | `hiflutter_tool` | CLI 工具（纯 Dart） | 无 | `args`、`path`、`yaml`、`yaml_edit` | 否 |

> 注：`hiflutter_suite` 因基于 Flutter 3.50+ 的 `gen-l10n`（`intl`）与剥离自 SDK 的 Material 3 组件库 `material_ui` 构建组件契约，故在 `package_rules.dart` 中特批引入该二项官方/准官方依赖；`hiflutter_suite_webview` 需将拦截到的外链转交给 `hiflutter_nav` 的 `HiLinkOpener`，故允许额外依赖 `hiflutter_nav`。

## 伞包 `hiflutter` 与按需选装原则

`packages/hiflutter/lib/hiflutter.dart` 重新导出全部 **14 个**标记为 ✓ 的包：

- `hiflutter_base`、`hiflutter_base_log_file`
- `hiflutter_core`、`hiflutter_core_device`
- `hiflutter_net`、`hiflutter_net_dio`
- `hiflutter_nav`、`hiflutter_nav_go_router`、`hiflutter_nav_url_launcher`
- `hiflutter_store`、`hiflutter_store_file`、`hiflutter_store_prefs`、`hiflutter_store_secure`
- `hiflutter_suite`

以下包故意排除在伞包之外，由消费项目按实际需要显式添加：

- **较重或含特定权限/渲染引擎的可选适配包**：`hiflutter_net_connectivity`（系统网络状态订阅）、`hiflutter_suite_cached_image`（图片磁盘缓存库）、`hiflutter_suite_webview`（WebView 原生视图）；
- **状态管理绑定**：`hiflutter_riverpod`，保证选用 Bloc 等其他方案的消费项目无需引入 Riverpod；
- **独立工具与示例**：`hiflutter_tool`（开发者 CLI）与 `apps/showcase`（`publish_to: none` 示例 App）。

此外，多模块消费项目也可不依赖伞包，仅按需引入单个契约包及其选定适配包，确保未使用的原生插件代码不进入构建产物。

## 明确不预置的能力

以下库或能力在 v0.1.0 设计中刻意排除，不作为仓库内置依赖引入：

- 商业厂商 SDK（友盟、Firebase、Sentry、EMAS 等）：需实际使用场景驱动再按单个独立适配包接入，不进入伞包。
- 第三方 `logger`、`toast` 与下拉刷新库：已由 `hiflutter_base` 日志与 `hiflutter_suite` 原生实现覆盖。
- 持久化数据库（Drift / Isar / Hive 等）、JSON 代码生成（`freezed` / `json_serializable`）、工作区管理工具 `melos`、断点续传、WebSocket、推送、支付、分享。
