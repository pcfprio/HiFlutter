# hiflutter_tool

Command-line tool for [HiFlutter](https://github.com/pcfprio/HiFlutter) consumer
projects. It switches `pubspec_overrides.yaml` between the three integration
modes without touching `pubspec.yaml`, preserving any non-HiFlutter overrides,
and verifies readiness before release builds.

## Commands

- **Source mode** (sibling checkout):
  ```sh
  hiflutter mode source [--project-dir <dir>] [--hiflutter-dir <dir>]
  ```
  Resolves the HiFlutter checkout (`--hiflutter-dir` > `HIFLUTTER_DIR` >
  `../HiFlutter`), computes the transitive closure of `hiflutter*` dependencies
  from the consumer `pubspec.yaml`, and writes relative POSIX `path` overrides
  into `pubspec_overrides.yaml`.

- **Pinned mode** (git tag):
  ```sh
  hiflutter mode pin <tag> [--project-dir <dir>] [--git-url <url>]
  ```
  Shallow-clones `<tag>` from `<url>` (defaulting to
  `https://github.com/pcfprio/HiFlutter.git`), computes the transitive closure of
  `hiflutter*` packages at that tag, and writes `git` overrides with `url`,
  `ref`, and `path` into `pubspec_overrides.yaml`.

- **Hosted mode** (pub.dev):
  ```sh
  hiflutter mode hosted [--project-dir <dir>]
  ```
  Removes tool-managed HiFlutter entries and markers from
  `pubspec_overrides.yaml`, deleting the file when no user-owned overrides
  remain.

- **Check**:
  ```sh
  hiflutter check [--release] [--project-dir <dir>] [--hiflutter-dir <dir>]
  ```
  Detects the active mode from `pubspec_overrides.yaml`:
  - `source`: reports whether the HiFlutter git working tree is clean or dirty;
    fails when `--release` is passed.
  - `pin`: resolves the upstream tag commit SHA with `git ls-remote` and checks
    that every managed `hiflutter*` package in `pubspec.lock` matches its
    `description.resolved-ref`.
  - `hosted`: succeeds with exit code `0`.

## Programmatic usage

See `example/main.dart` for invoking `HiToolRunner` directly from Dart.

## License

MIT
