# 可观测性与启动装配规范

本文件说明 HiFlutter 的分级多路由脱敏日志、隐私同意门控的数据统计与崩溃上报，以及全局错误捕获的装配顺序。

## 日志设计（`HiLogger` / `HiLog` / `HiFileLogSink`）

### 多路由与默认安全脱敏

- 一条日志通过 `HiLogger` 同时发往零个或多个 `HiLogRoute`，每条路由独立拥有自己的最低级别 `minLevel` 与脱敏策略 `redaction`：
  - 默认构造 `HiLogRoute(sink)` 采用 **`minLevel: HiLogLevel.info`**（丢弃 `HiLogLevel.debug`）与 **`redaction: const HiRedaction.standard()`**；
  - `HiRedaction.standard()` 会递归脱敏消息文本、错误描述以及任意嵌套深度的 `attributes` 中匹配敏感词的键（忽略大小写与 `-`、`_` 分隔符：`password`、`passwd`、`token`、`authorization`、`cookie`、`secret`、`apikey`、`privatekey`、`credential` 及额外配置的 `extraKeys`），同时遮蔽 Bearer 令牌、JWT 字符串、URL 中的敏感查询参数以及 `extraPatterns`，统一替换为 `HiRedaction.mask`（`'[REDACTED]'`）；
  - 仅在明确只落开发者本机控制台输出端等安全环境下，才可由调用方显式选择 `HiRedaction.none()`。
- **不可绕过约束**：`HiLogRecord` 仅限包内私有的 `HiLogger` 工厂构造，其所有字段及 `attributes` 均为不可变视图；任何自定义 `HiLogSink` 只会收到经各自路由过滤与脱敏完成后的只读记录，无法反向获取原文或跳过脱敏。
- **单路由故障隔离**：某个输出端 `write` 抛错会被隔离，不会中断主业务调用链或阻碍其他路由继续接收记录。
- **延迟构造与模块标签**：日志入参为 `String Function() message` 闭包，仅当至少有一条路由接受当前日志级别时才会求值（最多执行一次），避免高频 `debug` 日志在生产环境下产生无用字符串拼接开销；通过 `module`（如 `'net'`、`'error'`）与结构化 `attributes` 便于检索过滤。

### 一次性全局日志入口（ADR-0005）

- 全局静态入口 `HiLog` 仅应在应用组合根调用 `HiLog.install(logger)` 安装一次，**安装后严禁替换**，重复调用 `HiLog.install` 会立即抛出 `StateError`（详见 [ADR-0005](../adr/0005-global-log-entry-exception.md)）。
- 在 `HiLog.install` 调用之前，任何调用 `HiLog.debug` / `info` / `warning` / `error` / `log` 的行为均为安全空操作（既不抛出异常也不执行消息闭包）。

### 控制台与文件日志输出端

- `HiConsoleLogSink`（`hiflutter_base`）：通过 `dart:developer` `log` 输出带模块名与结构化属性的开发日志，并将错误与堆栈传递给 IDE 诊断工具。
- `HiFileLogSink`（`hiflutter_base_log_file`）：
  - 以文件命名格式 `hiflutter-<yyyy-MM-dd>.log` 按天轮转，单日超出 `maxFileBytes`（默认 5 MiB）时切分续写 `.1.log`、`.2.log`；
  - 每次切入新日期文件时清理超出 `retentionDays`（默认保留含当日共 7 天）的历史日志文件；
  - 写入采用同步无缓冲追写（`writeFromSync`），并配套 `HiFileLogSink.inApplicationSupport()` 便捷工厂与 `logFiles()` 方法导出按时间正序排列的文件列表。
  - **推荐做法**：面向导出或问题反馈的文件输出端必须保持默认 `HiRedaction.standard()`。

## 隐私同意门控与统计/崩溃上报

### 同意状态机（`HiConsent`）

- 状态枚举 `HiConsentStatus`：`unknown`（未决定）、`granted`（已明确同意）、`denied`（已明确拒绝）。
- **门控原则**：`HiConsent.isGranted` 仅在 `status == HiConsentStatus.granted` 时为 `true`；`unknown` 一律按未同意处理。状态变化通过广播流 `changes` 供外部监听。

### 数据统计（`HiAnalytics`）与崩溃上报（`HiCrashReporter`）

- 为保证厂商无关性，统计事件属性（`track` / `identify` / `page`）与崩溃上下文/面包屑值（`setContext` / `addBreadcrumb`）统一受限于密封的标量类 `HiScalar`（仅包裹 `String`、`int`、`double`、`bool` 四种子类型；`setContext` 传入 `null` 表示移除该键）。
- `hiflutter_base` 为两个契约各提供四类内置实现：
  1. `HiNoOpAnalytics` / `HiNoOpCrashReporter`：测试或关闭功能时使用；
  2. `HiConsoleAnalytics` / `HiConsoleCrashReporter`：开发期格式化控制台打印；
  3. `HiCompositeAnalytics` / `HiCompositeCrashReporter`：扇出至多个厂商后端，单个委托异常不阻碍其余委托执行，可通过可选 `onError` 回调集中收集异常；
  4. `HiConsentGatedAnalytics` / `HiConsentGatedCrashReporter`：包装真实或组合委托，当 `consent.isGranted` 为 `false`（包含 `unknown` 与 `denied`）时**直接丢弃调用而不排队缓存**；唯一例外是 **`HiAnalytics.reset()` 始终透传给底层委托**，确保用户在撤回同意或退出登录时仍可清除本地残留标识。

## 全局错误捕获与启动装配顺序

全局错误捕获由 `hiflutter_core` 中的 `HiErrorCapture` 提供；若使用可选应用骨架 `hiflutter_riverpod`，由 `HiRiverpodBootstrap.run` 自动封装以下严格的四步启动序列：

```text
1. HiLog.install(logger)
   └─ 安装全局不可替换日志入口，确保后续任何报错都能被记录。

2. HiErrorCapture.install(reporter: reporter, module: errorModule)
   ├─ 接管 FlutterError.onError（框架构建/布局异常以 fatal: false 上报，并透传旧处理器保留调试输出）
   └─ 接管 PlatformDispatcher.instance.onError（原生平台/未捕获同步平台错误以 fatal: true 上报并标记 handled）

3. capture.runGuarded(() async { ... })
   ├─ 在守护 Zone 内捕获所有未处理异步异常（以 fatal: true 上报崩溃并写入 HiLog.error）
   ├─ 调用 WidgetsFlutterBinding.ensureInitialized()（保证绑定与异常 Zone 同处一个 Zone）
   └─ 执行异步初始化准备（beforeRunApp），并构建 ProviderScope 注入全部契约覆盖

4. runApp(...)
   └─ 挂载根 Widget，启动 UI 渲染树
```

注意事项：
- 当 `HiErrorCapture` 向注入的 `HiCrashReporter` 转发异常（调用 `reporter.captureException`）且该上报器自身抛出异步或同步异常时，错误捕获器内部会自动捕获并通过 `HiLog.error` 记录降级日志，绝不引起二次崩溃循环。
- 业务与测试如需清理全局钩子（例如单测中），可持有并调用 `capture.dispose()` 还原测试前的 `FlutterError.onError` 与 `PlatformDispatcher.instance.onError`。
