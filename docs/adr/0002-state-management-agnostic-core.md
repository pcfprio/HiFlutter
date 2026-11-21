# 核心包不绑定状态管理，Riverpod 作为可选应用骨架

旧效率库全部押在 GetX 上（状态、路由、网络、依赖注入），导致所有模块耦合、难以替换，而且 GetX 维护风险高。HiFlutter 的核心包只依赖 Flutter 内置的 `Listenable` 与 `Stream`，不依赖任何状态管理库；另提供可选集成包 `hiflutter_riverpod` 作为推荐的应用骨架，由 Riverpod 同时承担依赖注入。这样外部用户使用 Bloc 等其他方案时仍可使用全部核心能力。

## Considered Options

- 全库绑定 Riverpod：使用更省事，但会把对外用户锁死在一个状态管理方案上。
- 全库绑定 Bloc：同上。
- 继续使用 GetX：维护风险高，旧库已证明它会把所有模块耦合在一起。
