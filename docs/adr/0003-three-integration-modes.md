# 消费项目通过覆盖文件在三种集成模式之间切换

消费项目在 `pubspec.yaml` 中只声明一份将来发布到 pub.dev 时也成立的 HiFlutter 依赖，用 pub 官方支持的 `pubspec_overrides.yaml` 决定实际来源：源码模式指向同级目录 `path`，锁定模式指向 git 版本 tag，发布模式则删除覆盖文件。之所以不像 HiIOS、HiAndroid、HiWeb 那样自写 SHA 版本锁和守护脚本，是因为 Dart 原生支持 `path`、git `ref` 与 `dependency_overrides`，而消费项目的 `pubspec.lock` 本身就会记录 git 依赖解析到的完整 SHA。

## Consequences

- HiFlutter 发布到 pub.dev 之前，锁定模式的覆盖文件必须列出消费项目用到的全部 `hiflutter_*` 包（含传递依赖），否则 pub 会去 pub.dev 查找尚不存在的包；这由模式切换工具自动生成。
- 源码模式下不得进行发布构建，由门禁检查拦截。
