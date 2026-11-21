# 编码与测试规范

本文件汇总在 HiFlutter 仓库编写与审查 Dart / Flutter 代码、UI 组件与测试时必须遵循的规范。

## 静态分析、格式与语言约定

- **代码格式化**：所有代码必须保持 `dart format .` 零变更（`FormatStage` 校验）。
- **静态分析规则**：工作区根与所有包均开启 `strict-casts: true`、`strict-inference: true`、`strict-raw-types: true` 与 `public_member_api_docs`（纯 Dart 包继承根 `analysis_options.yaml` 中的 `package:lints/recommended.yaml`，Flutter 包继承各自 `package:flutter_lints/flutter.yaml`）。
- **公开 API 文档注释**：所有包向外导出的类、接口、枚举、字段、方法、typedef 与顶级函数必须具备清晰准确的英文 dartdoc 注释；包内 `README.md` 与 `CHANGELOG.md` 同样使用英文；仓库级规则（`AGENTS.md`）、`docs/**/*.md` 与 GitHub Issue 使用简体中文。

## 命名、边界与依赖约束

1. **`Hi` 类型前缀**：所有公开导出的类、接口、枚举、mixin、extension 与 typedef 统一以 `Hi` 为前缀（如 `HiLogger`、`HiError`、`HiHttpClient`、`HiRoute`、`HiKeyValueStore`、`HiPrimaryButton`）；公开辅助顶级函数尽量以 `hi` 为前缀（如 `hiProviderOverrides`、`hiPaginationProvider`）。
2. **第三方类型隔离**：第三方依赖类型与异常只能停留在适配包内部实现或明确隔离的测试入口文件（如 `hiflutter_net_dio` 与 `hiflutter_core_device` 单独拆出的 `lib/testing.dart`）中，绝不出现在契约包、伞包或适配器主入口的签名与返回值里。
3. **禁止导入已弃用的 `package:flutter/material.dart`**：
   - 通用 Flutter 包（`hiflutter_core`、`hiflutter_nav`、`hiflutter_riverpod` 等）统一导入 `package:flutter/widgets.dart` 与 `package:flutter/foundation.dart`；
   - 需要 Material 3 组件时，仅可在 `tool/src/package_rules.dart` 明确允许依赖 `material_ui` 的 UI 包（`hiflutter_suite` 及其适配包）与 `apps/showcase` 中导入 `package:material_ui/material_ui.dart`。
4. **禁止全局可变单例（`HiLog.install` 例外）**：能力实例一律在应用组合根构建并通过构造器参数或 `hiflutter_riverpod` 的 `ProviderScope` 覆盖注入（[ADR-0002](../adr/0002-state-management-agnostic-core.md)、[ADR-0005](../adr/0005-global-log-entry-exception.md)）。禁止隐藏的静态服务定位器。
5. **业务词屏蔽**：所有文件、路径、变量、注释与测试案例均不得出现 `tool/business_terms.txt` 中的任何产品名或特定业务词汇（受 `TermsStage` 强制拦截）。

## 错误处理模型

- **单一密封异常根类型 `HiError`**：所有可预期失败必须归一为 `hiflutter_base` 中密封类 `HiError` 的十类子类型之一（`HiNetworkError`、`HiTimeoutError`、`HiUnauthorizedError`、`HiForbiddenError`、`HiNotFoundError`、`HiServerError`、`HiDecodeError`、`HiCancelledError`、`HiStorageError`、`HiUnknownError`），携带 `retryable` 与 `display`（`HiErrorDisplay`）。
- **严禁静默吞异常或泄漏原生异常**：适配层捕获平台异常（`DioException`、`PlatformException`、`FileSystemException` 等）后应映射为对应的 `HiError` 子类，把原异常作为 `_cause` 保留在 `diagnostics` 诊断文本中（不公开为强类型对象属性），并向上抛出。仅有 `HiLogger` 的路由写入与 `HiComposite*` 扇出允许按隔离原则隔离单路输出端失败以免阻塞正常主流程。

## UI 组件与跨端视觉契约

- `hiflutter_suite` 以 Material 3（`material_ui`）为基准构建，公开度量常量集中维护在 `HiSuiteMetrics`，关键尺寸与 HiIOS / HiAndroid 的 `SuiteCore` 规范保持对齐（如标准列表行最小高度 `52.0`、搜索框高度 `48.0`、主按钮最小高度与最小点击区域 `48.0`、水平安全边距 `16.0`、加载更多页尾最小高度 `52.0`、居中加载圈直径 `48.0`）。
- 默认支持中英文双语 `gen-l10n`（`HiSuiteLocalizations`），允许消费项目通过 `LocalizationsDelegate` 或组件构造函数入参直接覆盖具体文案。
- 组件状态逻辑与状态机（如 `HiPaginationController`）须保持与 UI 解耦的 `ChangeNotifier`，避免耦合进 BuildContext 或特定状态管理框架。

## 测试规范与 TDD 准则

实施新功能与缺陷修复遵循红-绿-重构 TDD 节奏，且严格遵守以下边界：

1. **公开入口即唯一测试缝（seam）**：
   - 测试文件（`test/*_test.dart`）必须只导入包自己的公开库入口（如 `package:hiflutter_net/hiflutter_net.dart`），**禁止直接 import `package:.../src/...` 内部文件或断言私有字段与内部调用次序**。
   - 测试只断言外部可观察行为：返回值、抛出 `HiError` 类型与属性、sink 收到的 `HiLogRecord`、存储读回结果、Widget 渲染节点与点击交互结果。
2. **第三方库最低替换点假实现**：
   - 适配包不连接真实网络或依赖真机通道；在第三方库官方提供的最低接口替换点注入轻量假实现：
     - `hiflutter_net_dio`、`hiflutter_core_device`：通过各自隔离的 `lib/testing.dart` 传入伪造 Dio `HttpClientAdapter` 或跨平台 `BaseDeviceInfo` 加载器；
     - `path_provider`、`device_info_plus`、`package_info_plus`、`connectivity_plus`、`url_launcher`、`shared_preferences`、`flutter_secure_storage`、`webview_flutter`：在测试 `setUp` 中注册各自的 `*_platform_interface` 假平台实现；
     - `hiflutter_nav_go_router`：直接在 `testWidgets` 中构建真实 `HiGoRouterNavigator` 驱动界面跳转与深链解析；
     - `hiflutter_suite_cached_image`：注入可控的缓存/图片加载边界并在 Widget 测试中校验状态视图与点击交互。
3. **共享契约测试**：同一契约的内存实现（如 `HiKeyValueStore.memory()`）与各平台适配实现应运行同一套共享契约行为测试套件，确保行为等价与安全守卫（如凭据键拒绝、路径穿越拒绝）一致。
4. **Workspace 测试执行位置**：在 Flutter pub workspace 中涉及包内资源或 shader（如 `apps/showcase` 加载 `material_ui` 资源）的 Widget 测试，须在对应包根目录运行 `flutter test`，或统一在仓库根目录执行 `dart run tool/check.dart --only test`（`TestStage` 会按工作区成员逐包切换工作目录执行测试）。
5. **暂不引入黄金图测试**：跨机器字体与像素渲染存在环境差异，v0.1.0 不强制黄金图测试，但要求每个公开 API 行为均有对应行为测试覆盖。
