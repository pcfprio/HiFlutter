# 包名采用 `hiflutter` / `hiflutter_*` 前缀

pub.dev 上的 `hi_base`、`hi_core`、`hi_log`、`hi_logger`、`hi_flutter`、`hi_nav` 已被作者旧的 GetX 效率库占用。复用这些名称会让新库从 `2.0.0` 起步，与旧库共用 pub.dev 版本历史，同一前缀下还会新旧包混杂。因此新库采用尚未被占用的 `hiflutter`（伞包）与 `hiflutter_*`（子包），从 `0.1.0` 干净起步，命名与 HiWeb 的 `hiweb-*` 对齐；旧 `hi_*` 包日后在 pub.dev 标记为 discontinued 并指向新包。
