# AGENTS.md

本文件是在 HiFlutter 仓库中工作的智能体（Claude Code、Codex 等）的项目级规则入口。`CLAUDE.md` 通过 `@AGENTS.md` 引入本文件。

## 语言约定

项目级智能体规则与协作/领域文档（`AGENTS.md`、`docs/agents/*.md`、`GLOSSARY.md`、`GLOSSARY-MAP.md`、`docs/adr/*.md`、Issue / PR / Spec 正文等）一律使用简体中文撰写；命令、路径、代码标识符、仓库名与固定标签名（如 `needs-triage`）保持原样。

## Agent skills

### Issue tracker

Issue 与 Spec 存放在 GitHub 仓库 `pcfprio/HiFlutter` 的 Issues 中，通过 `gh` CLI 操作。详见 `docs/agents/issue-tracker.md`。

### Triage labels

使用默认的五个分诊标签：`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`。详见 `docs/agents/triage-labels.md`。

### Domain docs

单上下文（single-context）布局：仓库根目录一个 `GLOSSARY.md`，架构决策记录放在 `docs/adr/`。详见 `docs/agents/domain.md`。
