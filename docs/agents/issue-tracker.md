# Issue 跟踪器：GitHub

本仓库的 Issue 与 Spec 以 GitHub Issues 的形式存放在 `pcfprio/HiFlutter`。所有操作都使用 `gh` CLI。

## 约定

- **创建 Issue**：`gh issue create --title "..." --body "..."`。多行正文用 heredoc。
- **读取 Issue**：`gh issue view <number> --json number,title,body,labels,comments`。
- **列出 Issue**：`gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`，并按需加上 `--label` 与 `--state` 过滤。
- **把 Issue 设为父 Issue 的子 Issue**：`gh issue create --parent <parent> ...`，或事后执行 `gh issue edit <parent> --add-sub-issue <child>`（需 `gh` 2.94+）。旧版 `gh`：`gh api --method POST repos/<owner>/<repo>/issues/<parent>/sub_issues -F sub_issue_id=<child-db-id>`（使用数据库 id，见下文 **阻塞关系**）。不支持子 Issue 时，在子 Issue 正文顶部写 `Part of #<parent>`。
- **阻塞关系**：使用 GitHub **原生 Issue 依赖**，这是规范且在界面可见的表示方式。用 `gh issue create --blocked-by <n>,<n> ...` 或 `gh issue edit <child> --add-blocked-by <blocker>` 添加依赖边（需 `gh` 2.94+）。旧版 `gh`：`gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`，其中 `<blocker-db-id>` 是阻塞方的数字**数据库 id**（`gh api repos/<owner>/<repo>/issues/<n> --jq .id`，_不是_ `#number`，也不是 `node_id`）。不支持依赖时，退而在子 Issue 正文顶部写一行 `Blocked by: #<n>, #<n>`。所有阻塞方都关闭后，该工单即解除阻塞。
- **统计未关闭的阻塞方**：`gh api repos/<owner>/<repo>/issues/<n> --jq .issue_dependencies_summary.blocked_by`（只计未关闭的阻塞方；为 0 表示可以开工）。`gh issue view <n> --json blockedBy` 也会列出已关闭的阻塞方，需要过滤：`--jq '[.blockedBy.nodes[] | select(.state == "OPEN")] | length'`。
- **评论 Issue**：`gh issue comment <number> --body "..."`
- **添加 / 移除标签**：`gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **关闭**：先用 `gh issue comment <number> --body "..."` 写明原因，再 `gh issue close <number>`。对已关闭的 Issue 执行 `gh issue close --comment` 会丢弃评论且仍返回 0。

仓库从 `git remote -v` 推断；在克隆目录内运行时 `gh` 会自动识别。

只向用户自己的仓库提交 Issue。除非用户拥有 `mattpocock/skills`（这些技能的来源仓库），否则绝不向其提交。在 fork 中 `gh` 可能默认指向上游父仓库，因此每个会话第一次执行 `gh issue create` 前，先用 `gh repo view --json nameWithOwner` 核对目标；若不是用户自己的仓库，先向用户确认。

## 把 PR 作为分诊入口

**PRs as a request surface: no.** _（若本仓库把外部 PR 视为功能请求，改为 `yes`；`/triage` 会读取此标志。）_

设为 `yes` 时，PR 与 Issue 走同一套标签和状态，使用对应的 `gh pr` 命令：

- **读取 PR**：`gh pr view <number>`，然后 `gh pr view <number> --comments`（非 TTY 下 `--comments` 只输出评论，不含正文），再用 `gh pr diff <number>` 查看差异。
- **列出待分诊的外部 PR**：`gh api --paginate 'repos/{owner}/{repo}/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, author_association, labels: [.labels[].name]}'`。
- **评论 / 打标签 / 关闭**：`gh pr comment`、`gh pr edit --add-label`/`--remove-label`、`gh pr close`。

GitHub 的 Issue 与 PR 共用同一编号空间，单独的 `#42` 可能是任意一种：先用 `gh pr view 42` 解析，失败再回退到 `gh issue view 42`。

## 当技能要求“publish to the issue tracker”时

创建一个 GitHub Issue。

## 当技能要求“fetch the relevant ticket”时

按上文 **读取 Issue** 的方式读取。

## Wayfinding operations（寻路操作）

供 `/wayfinder` 使用。**map（地图）** 是单个 Issue，**child（子工单）** 是它下面的各个 Issue。

- **Map**：单个带 `wayfinder:map` 标签的 Issue，正文包含 Notes / Decisions-so-far / Fog 三部分。`gh issue create --label wayfinder:map`。
- **子工单**：以 GitHub 子 Issue 方式挂到 map 下（见 **把 Issue 设为父 Issue 的子 Issue**）。未启用子 Issue 时，把子工单加入 map 正文的任务列表，并在子工单正文顶部写 `Part of #<map>`。标签：`wayfinder:<type>`（`research`/`prototype`/`grilling`/`task`）。被认领后，工单指派给推进它的开发者。
- **阻塞**：见“约定”中的 **阻塞关系**。
- **前沿查询（Frontier query）**：列出 map 下未关闭的子工单（`gh issue list --state open`，限定在 map 的子 Issue / 任务列表范围内），剔除仍有未关闭阻塞方（见 **统计未关闭的阻塞方**，或 `Blocked by` 行中有未关闭的 Issue）或已有指派人的工单；按 map 中的顺序取第一个。
- **认领**：`gh issue edit <n> --add-assignee @me`，这是本会话的第一次写操作。
- **解决**：`gh issue comment <n> --body "<answer>"`，然后 `gh issue close <n>`，再把上下文指针（要点 + 链接）追加到 map 的 Decisions-so-far。
