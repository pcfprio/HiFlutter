# 采用多包 pub workspace，按契约包、适配包、伞包分层

Flutter 的消费项目只要在 pubspec 中声明了某个含原生实现的第三方包，该包的原生代码就会编译进 App，权限声明也会合并进去，即使 Dart 代码从未 import 过它。单包会把所有预置原生插件强加给每个消费项目，增大包体，甚至因声明未使用的权限而被商店审核拒绝。因此 HiFlutter 以 pub workspace 管理多个包：契约包不依赖第三方，每个第三方库或厂商 SDK 各占一个适配包，伞包 `hiflutter` 只聚合默认的非厂商实现；分包细粒度接入的消费项目可以只选最小子集。

## Considered Options

- 单包加多个 library 入口（`package:hiflutter/net.dart`）：维护最省事，但无法避免插件的原生代码与权限被强制带入。
- 不设伞包（HiWeb 的做法）：Web 端有 tree-shaking 与 SSR 方面的顾虑，Flutter 没有，提供可选伞包能降低接入成本。
