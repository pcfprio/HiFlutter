# 版本号、发版、发布与维护分支规范

本文件定义 HiFlutter 多包仓库的版本号演进规则、统一改版工具以及“发版（Git tag）”与“发布（pub.dev）”分离的交付流程。

## 统一版本号规则

- **全仓单版本**：HiFlutter 全部 20 个可发布包始终共享同一 SemVer 版本号（v0.1.0 起步）；包间依赖约束统一声明为 `^<当前版本>`，在仓库根 pub workspace 内本地解析。
- **不发布标识**：可发布包的 `pubspec.yaml` 不写 `publish_to: none`；仅仓库根 `pubspec.yaml`（`hiflutter_workspace`）与示例 App `apps/showcase/pubspec.yaml` 声明 `publish_to: none`。
- **SemVer 与 `0.x` 演进语义**：
  - `0.x` 对外正式发布前（`0.y.z`）：patch 递增（`0.y.z -> 0.y.(z+1)`）表示兼容更新与缺陷修复；minor 递增（`0.y.z -> 0.(y+1).0`）可视为破坏性更新，仓库不保留废弃别名或向后兼容垫片，但必须在相关包的 `CHANGELOG.md` 写明迁移要点。
  - 进入 `1.0.0` 及以后严格遵循标准 SemVer（MAJOR 破坏性更新、MINOR 向下兼容新增、PATCH 向下兼容修复）。

## 统一升级版本号（`tool/bump_version.dart`）

禁止手工逐包修改版本号，统一使用仓库脚本：

```bash
dart run tool/bump_version.dart [--root <dir>] <version>
```

脚本行为说明（见 `tool/src/bump_version.dart`）：

1. 校验 `<version>` 是合法的 SemVer，且严格大于当前全部可发布包版本；否则以非零退出码拒绝（用法错误返回 `64`，版本未前进返回 `1`）。
2. 遍历工作区全部成员：
   - 对所有可发布包更新 `pubspec.yaml` 的 `version` 为 `<version>`；
   - 对所有成员（包含非发布成员）更新 `dependencies` 和 `dev_dependencies` 中对其它工作区成员的约束为 `^<version>`；
   - 对所有可发布包更新 `CHANGELOG.md`：若文件顶部包含 `## Unreleased` 标题，直接替换为 `## <version>`；若无未发布条目，则在顶部插入 `## <version>\n\n- Version alignment (no changes).`。
3. **注意事项**：`hiflutter_tool` 源码与文档中不会写死版本号占位符，运行 `bump_version.dart` 不会改动业务代码。日常在 `dev` 开发阶段若有可感知行为变更，应随 PR 在对应包的 `CHANGELOG.md` 顶部维护 `## Unreleased` 节。

## 发版（Git Tag）与发布（pub.dev）

**重要约定**：**发版**与**发布**是两项严格分离的操作，除非维护者明确下达指令，否则任何代码实施、PR 合并或日常维护均**不得修改 `main` 分支、不得打任何 Git tag、不得运行不带 `--dry-run` 的 `pub publish`**。

### 发版流程（在 `main` 打 Git Tag，供锁定模式消费）

仅在维护者明确决定为某个版本发版时执行：

1. 在 `dev` 分支运行 `dart run tool/bump_version.dart <version>` 统一对齐版本与 `CHANGELOG.md`，确认各破坏性改动包的迁移要点完整。
2. 运行全量验证（包含示例 App 原生构建冒烟）：
   ```bash
   flutter pub get
   dart run tool/check.dart --build
   ```
   确认全部 9 个阶段通过，工作区完全干净。
3. 将 `dev` 合入 `main` 并推送 `main`。
4. 在 `main` 的发版提交上打 Annotated Tag 并推送：
   ```bash
   git tag -a v<version> -m "Release v<version>"
   git push origin v<version>
   ```
5. **不可覆盖原则**：已经打出的发版 tag（及已发布版本）视为不可变快照，**绝不移动、删除重建或覆盖已发版 tag**，也绝不 `--force` 推送 `main` 或 `v*`。发现问题必须通过递增 patch 版本发新 tag 解决。

### 发布流程（上传至 pub.dev，供发布模式消费）

仅在维护者明确指令对外公开仓库（当前处于“暂不发布但随时具备发布条件”阶段）时执行：

1. 切换到已打好且通过 `dart run tool/check.dart --build` 的 `v<version>` 发版 tag 对应提交，再次核对 `publish` 阶段（`pub publish --dry-run`）全数零警告零错误。
2. 按无环拓扑依赖顺序逐层发布到 pub.dev（`hiflutter_base` → 其余 5 个契约包与 `hiflutter_base_log_file` → 各适配包 → `hiflutter_riverpod` → 伞包 `hiflutter` → 工具包 `hiflutter_tool`）。
3. 将早期旧版 pub.dev 上的 `hi_*` 包按 [ADR-0001](../adr/0001-hiflutter-package-prefix.md) 标记为 discontinued 并引导至对应的 `hiflutter` / `hiflutter_*` 新包。

## 维护分支规则

- **默认策略**：鼓励消费项目通过 `hiflutter mode pin <最新tag>` 直接升级到最新版本并对照 `CHANGELOG.md` 适配。
- **维护分支例外**：仅当某个已发版消费项目遇到阻塞性线上问题、且此时 `dev`/`main` 已演进多个破坏性版本导致该消费项目升级代价过大时，维护者方可决定启用维护分支：
  1. 从该消费项目当前锁定的发版 tag（如 `v0.1.0`）切出维护分支（如 `maint/v0.1`）；
  2. 只在该分支合入最小修复补丁；
  3. 对维护分支执行版本号递增（如 `0.1.1`），跑通完整 `dart run tool/check.dart --build`，在维护分支对应修复提交上打出补丁 tag `v0.1.1`（不得回合并覆写原 tag，按需另行把修复 cherry-pick 回 `dev`）。
