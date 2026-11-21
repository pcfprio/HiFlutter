# AGENTS.md

本文件是在 HiFlutter 仓库中工作的智能体（Claude Code、Codex 等）的项目级规则入口。`CLAUDE.md` 通过 `@AGENTS.md` 引入本文件。

## 语言约定

- 项目级智能体规则、领域与协作/工程文档（`AGENTS.md`、`README.md`、`docs/**/*.md`、`GLOSSARY.md`、Issue / PR / Spec 正文与评论等）一律使用简体中文撰写；命令、路径、代码标识符、仓库名与固定标签名（如 `needs-triage`、`deps-breaking`）保持原样。
- 各独立包内的 `packages/*/README.md`、`packages/*/CHANGELOG.md`、dartdoc 注释与 Git 提交信息使用英文。
- 领域术语以根目录 [GLOSSARY.md](GLOSSARY.md) 为准，不使用其中明确避免的同义词。

## 硬边界

1. **业务无关**：HiFlutter 仅提供通用基础设施，禁止任何消费产品名或特定业务概念进入代码、路径或文档；受 `tool/business_terms.txt` 与 `TermsStage` 强制扫描拦截。
2. **契约包零第三方依赖**：契约包仅可依赖 Dart 官方 `meta`、`collection`（Flutter 契约包可依赖 Flutter SDK，`hiflutter_suite` 例外允许 `intl`、`flutter_localizations` 与 `material_ui`）；第三方实现与厂商 SDK 一律放入独立适配包。
3. **第三方类型不穿透**：第三方库或插件的类型与异常不得出现在契约包公开接口、伞包导出面或未标明测试用途的适配包公开入口中。
4. **严格依赖方向与无环**：包间依赖必须符合 `tool/src/package_rules.dart` 允许表且禁止成环，新增或调整包依赖前必须先核对规则表。详见 `docs/architecture/packages.md`。
5. **禁止全局可变单例（日志除外）**：能力一律通过构造器注入或 `hiflutter_riverpod` 组合根覆盖提供；仅 `HiLog.install` 允许作为一次性的全局日志入口（ADR-0005），安装后不可替换。
6. **使用 `widgets.dart` 与 `material_ui`**：Flutter 代码导入 `package:flutter/widgets.dart`，Material 3 组件导入 `package:material_ui/material_ui.dart`；工作区全成员的 `package:flutter/material.dart` 导入/导出已由 `dart run tool/check.dart` 的 `deps` 阶段（`DepsStage`）自动拦截，细则见 `docs/engineering/coding.md`。
7. **厂商 SDK 不预建**：友盟、Firebase、Sentry、EMAS 等商业厂商 SDK 暂不预建适配包，待具体消费项目需要时再新增独立适配包。
8. **伞包不初始化**：伞包 `hiflutter` 只重新导出核心契约与默认非厂商适配包的自有公开 API，不得导出第三方类型或触发任何自动初始化。
9. **未发布期轻量化演进**：`0.x` 对外正式发布前不保留向后兼容垫片或废弃别名；发生破坏性调整时，直接同步更新相关包及对应包 `CHANGELOG.md` 的迁移要点。
10. **发版与发布由维护者决定**：修改代码、合并 `dev` 不得擅自修改 `main` 分支、打任何 git tag、或运行真实 `pub publish`；发版（`main` 打 tag）与发布（上传 pub.dev）相互独立，仅在维护者明确要求时执行。详见 `docs/engineering/release.md`。

## 验证门禁

- 任何代码或文档改动完成后，提交前必须运行总检查并确认全部阶段通过：
  - 常规改动：`dart run tool/check.dart`
  - 涉及示例 App `apps/showcase` 原生构建或宿主配置：`dart run tool/check.dart --build`
- 新增与修改功能按 TDD 实施，公开 API 须有英文 dartdoc；成员包测试仅导入公开库入口（`deps` 阶段自动拦截直接导入 `src/`）。详见 `docs/engineering/coding.md`。

## 文档导航

需要深入某类上下文时按需读取对应文档（完整索引见 `docs/README.md`）：

- **调整包结构、新增包或改动依赖**：读 `docs/architecture/packages.md` 与 `docs/adr/0001`–`0004`
- **引入、升级或排查第三方依赖冲突/破坏性更新**：读 `docs/engineering/dependencies.md`
- **使用或维护消费项目集成模式与发布检查**：读 `docs/engineering/integration.md` 与 `docs/adr/0003-three-integration-modes.md`
- **执行统一版本升级、发版或维护分支**：读 `docs/engineering/release.md`
- **编写 Dart/Flutter 代码、异常、UI 组件或测试**：读 `docs/engineering/coding.md`
- **改动日志、脱敏、统计/崩溃上报或全局错误捕获**：读 `docs/engineering/observability.md` 与 `docs/adr/0005-global-log-entry-exception.md`

## Agent skills

### Issue tracker

Issue 与 Spec 存放在 GitHub 仓库 `pcfprio/HiFlutter` 的 Issues 中，通过 `gh` CLI 操作。详见 `docs/agents/issue-tracker.md`。

### Triage labels

使用默认的五个分诊标签：`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`；另有工作流维护的非分诊标签 `deps-breaking`。详见 `docs/agents/triage-labels.md`。

### Domain docs

单上下文（single-context）布局：仓库根目录一个 `GLOSSARY.md`，架构决策记录放在 `docs/adr/`。详见 `docs/agents/domain.md`。
