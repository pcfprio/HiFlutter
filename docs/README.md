# HiFlutter 文档索引

本目录存放 HiFlutter 多包仓库的架构说明、工程规范、架构决策记录（ADR）与智能体协作约定。术语标准以根目录 [GLOSSARY.md](../GLOSSARY.md) 为准。

## 入口与概览

- [项目说明（README）](../README.md)：面向对象消费项目的使用指南、包一览、集成模式快速上手与仓库常用命令
- [项目级智能体规则（AGENTS.md）](../AGENTS.md)：仓库硬边界、开发验证门禁与 `CLAUDE.md` 引入入口
- [领域术语表（GLOSSARY.md）](../GLOSSARY.md)：统一定义包结构、集成模式、版本与可观测性领域术语及禁用同义词

## 架构与决策记录（Architecture & ADRs）

- [包家族、角色与依赖方向](architecture/packages.md)：五类包角色、允许依赖矩阵、伞包成员与不预置清单
- [ADR-0001：包名采用 `hiflutter` / `hiflutter_*` 前缀](adr/0001-hiflutter-package-prefix.md)
- [ADR-0002：核心包不绑定状态管理，Riverpod 作为可选应用骨架](adr/0002-state-management-agnostic-core.md)
- [ADR-0003：消费项目通过覆盖文件在三种集成模式之间切换](adr/0003-three-integration-modes.md)
- [ADR-0004：采用多包 pub workspace，按契约包、适配包、伞包分层](adr/0004-multi-package-workspace.md)
- [ADR-0005：日志是"禁止全局可变单例"的唯一例外](adr/0005-global-log-entry-exception.md)

## 工程规范（Engineering）

- [第三方依赖准入、版本基线与更新流程](engineering/dependencies.md)：准入清单、预置版本基线表、caret 兼容策略与 `deps-breaking` 处理流程
- [消费项目集成模式与接入规则](engineering/integration.md)：源码/锁定/发布模式原理、`hiflutter` CLI 完整命令与可供消费项目直接引用的门禁规范
- [版本对齐、发版、发布与维护分支](engineering/release.md)：统一版本号与 `tool/bump_version.dart`、发版（tag）与发布（pub.dev）分离约束、维护分支策略
- [编码与测试规范](engineering/coding.md)：strict 静态分析、语言约定、`Hi` 前缀、错误处理、UI 度量对齐与基于公开入口的 TDD 测试原则
- [可观测性与全局启动装配](engineering/observability.md)：日志多路由与不可绕过脱敏、`HiConsent` 隐私门控、统计/崩溃上报隔离及启动装配顺序

## 智能体协作流程（Agents）

- [Issue 跟踪器约定](agents/issue-tracker.md)：`pcfprio/HiFlutter` 上使用 `gh` CLI 操作 Issue、父子关系与原生阻塞依赖的约定
- [分诊标签与专用标签映射](agents/triage-labels.md)：五个分诊角色标签以及自动化流程维护的非分诊标签 `deps-breaking`
- [领域文档布局规范](agents/domain.md)：单上下文布局及使用 `GLOSSARY.md` 与 `docs/adr/` 的规范
