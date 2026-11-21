# 消费项目集成模式与接入规则

消费项目在自身 `pubspec.yaml` 中只维护一份静态的 HiFlutter 依赖声明（如 `^0.1.0`），通过 `hiflutter` CLI 工具读写 `pubspec_overrides.yaml` 在**源码模式**、**锁定模式**与**发布模式**之间切换（详见 [ADR-0003](../adr/0003-three-integration-modes.md)）。

## 工具安装

`hiflutter_tool` 以独立可执行命令 `hiflutter` 发布在 `packages/hiflutter_tool/` 下，全局激活命令如下（与具体消费项目所处模式无关，建议直接使用本地 HiFlutter 克隆路径安装）：

```bash
dart pub global activate --source path <HiFlutter>/packages/hiflutter_tool
```

验证安装：

```bash
hiflutter --help
```

> 请确保 `~/.pub-cache/bin`（或 Dart pub 全局 bin 目录）已加入 `PATH`。

## 三种集成模式与原理

`hiflutter` 工具只在消费项目的 `pubspec_overrides.yaml` 内维护一段带标记注释的区块，**绝不修改消费项目的 `pubspec.yaml`**，并完整保留用户在 `pubspec_overrides.yaml` 中自行编写的其他非 HiFlutter 覆盖与注释：

```yaml
# hiflutter-tool:mode=source
dependency_overrides:
  # BEGIN HIFLUTTER MANAGED
  hiflutter_base:
    path: ../HiFlutter/packages/hiflutter_base
  # END HIFLUTTER MANAGED
```

切换或检查模式时，`hiflutter` 自动解析消费项目 `pubspec.yaml` 中声明的 `hiflutter` 与 `hiflutter_*`（含 `dependencies` 与 `dev_dependencies`），计算全部间接内部传递依赖闭包后写入覆盖区块（同时自动忽略 `publish_to: none` 的根工作区和 `apps/showcase`）。

### 1. 源码模式（`source`）

适用于正在积极联调并同步演进 HiFlutter 的开发中消费项目：

```bash
hiflutter mode source [--project-dir|-p <dir>] [--hiflutter-dir <dir>]
flutter pub get
```

- 目标 HiFlutter 仓库目录解析优先级：`--hiflutter-dir` > 环境变量 `HIFLUTTER_DIR` > 消费项目同级目录 `../HiFlutter`。
- 在 `pubspec_overrides.yaml` 写入模式头 `# hiflutter-tool:mode=source` 及各包的 POSIX 相对 `path` 覆盖，使消费项目编译、热重载直接命中本地 HiFlutter 源码。

### 2. 锁定模式（`pin`）

适用于需要稳定版本、在 HiFlutter 尚未对外发布到 pub.dev 期间进行测试/发布构建的消费项目：

```bash
hiflutter mode pin <tag> [--project-dir|-p <dir>] [--git-url <url>]
flutter pub get
```

- 默认 Git 仓库地址为 `https://github.com/pcfprio/HiFlutter.git`（可通过 `--git-url` 覆盖为本地克隆路径或镜像 URL，便于离线与 CI 演练）。
- 工具会浅克隆指定 `<tag>`，基于该版本快照计算完整传递依赖闭包，并在 `pubspec_overrides.yaml` 写入模式头 `# hiflutter-tool:mode=pin tag=<tag> url=<gitUrl>` 与对应的 `git`（`url`、`ref`、`path`）覆盖，防止 pub 前往 pub.dev 查找尚未公开的包。

### 3. 发布模式（`hosted`）

适用于 HiFlutter 对外正式发布到 pub.dev 后：

```bash
hiflutter mode hosted [--project-dir|-p <dir>]
flutter pub get
```

- 清除 `pubspec_overrides.yaml` 中由 `hiflutter-tool` 托管的标记区块与模式头。
- 若移除后文件中无用户自有覆盖条目，则直接删除 `pubspec_overrides.yaml`；若仍有用户自有覆盖条目，则完整保留。

## 模式检查与发布门禁（`hiflutter check`）

```bash
hiflutter check [--release] [--project-dir|-p <dir>] [--hiflutter-dir <dir>]
```

各模式下的检查行为与退出码语义：

| 当前模式 | `hiflutter check` 行为 | 附加 `--release` 行为 |
| --- | --- | --- |
| `hosted` | 报告 `Mode: hosted` 并返回 `0` | 同左，返回 `0` |
| `source` | 报告 `Mode: source` 及关联 HiFlutter 工作区 Git 状态（`clean` / `dirty`），返回 `0` | **以退出码 `1` 失败**，阻止把未发版源码打包发往商店或外部环境 |
| `pin` | 核对远端/目标仓库 `<tag>` 解析出的真实提交 SHA，与消费项目 `pubspec.lock` 中所有托管包的 `source: git` 与 `resolved-ref` 逐一比对；不一致时返回非零退出码 | 同左，严格校验全匹配后才返回 `0` |

> 使用 `hiflutter mode source` 或 `hiflutter mode pin <tag>` 切换模式后，必须紧接着运行 `flutter pub get`（或 `dart pub get`）刷新 `pubspec.lock`，再执行 `hiflutter check`。

## 消费项目接入规范（供消费项目 `AGENTS.md` 引用）

以下规范供依赖 HiFlutter 的消费项目直接引用或内联到其 `AGENTS.md` 中：

```markdown
## HiFlutter 依赖与发布门禁

- 在 `pubspec.yaml` 中只声明发布后同样有效的 HiFlutter 版本依赖（如 `^0.1.0`），禁止直接把 `path:` 或 `git:` 写进 `pubspec.yaml`。
- 禁止手工改写 `pubspec_overrides.yaml` 中 `# BEGIN HIFLUTTER MANAGED` 与 `# END HIFLUTTER MANAGED` 区块内的条目，一律通过 `hiflutter` CLI 维护：
  - 日常开发与效率库联调：`hiflutter mode source && flutter pub get`
  - 冻结到指定 HiFlutter 发版版本：`hiflutter mode pin <tag> && flutter pub get`（须将 `pubspec_overrides.yaml` 与 `pubspec.lock` 一并提交以保证可复现构建）
  - 切换为 pub.dev 正式版本：`hiflutter mode hosted && flutter pub get`
- 在构建 Release / 测试分发包（APK、AAB、IPA）或合并发布分支前，CI 与本地构建前必须先执行 `hiflutter check --release`；源码模式下禁止打包发布。
- 升级 HiFlutter 锁定 tag 时，按目标版本区间检查所依赖包的 `CHANGELOG.md` 迁移要点（`0.x` 未发布期不保证跨 minor 向后兼容）。
```
