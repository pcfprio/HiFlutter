/// The allowed-dependency table from Spec #2 ("包家族与依赖方向").
///
/// Every HiFlutter package, including ones not created yet, is listed here
/// with the internal packages it may depend on. A new package must be added
/// here before the deps stage accepts it.
library;

/// What kind of package a [PackageRule] describes.
enum PackageRole {
  /// Defines HiFlutter-owned types only; no third-party dependencies.
  contract,

  /// Implements a contract with a third-party library.
  adapter,

  /// Optional application skeleton (`hiflutter_riverpod`).
  integration,

  /// The `hiflutter` umbrella package.
  umbrella,

  /// The `hiflutter` command-line tool.
  tool,
}

/// Dependency rule for one package.
class PackageRule {
  /// Creates a rule.
  const PackageRule(
    this.role, {
    this.internal = const {},
    this.flutter = false,
    this.extraThirdParty = const {},
  });

  /// Package kind.
  final PackageRole role;

  /// HiFlutter packages this package may depend on.
  final Set<String> internal;

  /// Whether a contract package may depend on the Flutter SDK.
  final bool flutter;

  /// Extra third-party packages a contract package may depend on beyond
  /// [contractThirdParty].
  final Set<String> extraThirdParty;
}

/// Third-party packages every contract package may depend on.
const contractThirdParty = {'meta', 'collection'};

const _base = 'hiflutter_base';
const _core = 'hiflutter_core';
const _net = 'hiflutter_net';
const _nav = 'hiflutter_nav';
const _store = 'hiflutter_store';
const _suite = 'hiflutter_suite';

/// Contract packages, which `hiflutter_riverpod` may depend on.
const _contracts = {_base, _core, _net, _nav, _store, _suite};

/// Packages marked ✓ for the umbrella in the Spec table.
const _umbrellaMembers = {
  _base,
  'hiflutter_base_log_file',
  _core,
  'hiflutter_core_device',
  _net,
  'hiflutter_net_dio',
  _nav,
  'hiflutter_nav_go_router',
  'hiflutter_nav_url_launcher',
  _store,
  'hiflutter_store_prefs',
  'hiflutter_store_secure',
  'hiflutter_store_file',
  _suite,
};

/// Rule per package name.
const packageRules = <String, PackageRule>{
  // base
  _base: PackageRule(PackageRole.contract),
  'hiflutter_base_log_file': PackageRule(
    PackageRole.adapter,
    internal: {_base},
  ),
  // core
  _core: PackageRule(PackageRole.contract, internal: {_base}, flutter: true),
  'hiflutter_core_device': PackageRule(
    PackageRole.adapter,
    internal: {_core, _base},
  ),
  // net
  _net: PackageRule(PackageRole.contract, internal: {_base}),
  'hiflutter_net_dio': PackageRule(
    PackageRole.adapter,
    internal: {_net, _base},
  ),
  'hiflutter_net_connectivity': PackageRule(
    PackageRole.adapter,
    internal: {_net, _base},
  ),
  // nav
  _nav: PackageRule(PackageRole.contract, internal: {_base}, flutter: true),
  'hiflutter_nav_go_router': PackageRule(
    PackageRole.adapter,
    internal: {_nav, _base},
  ),
  'hiflutter_nav_url_launcher': PackageRule(
    PackageRole.adapter,
    internal: {_nav, _base},
  ),
  // store
  _store: PackageRule(PackageRole.contract, internal: {_base}),
  'hiflutter_store_prefs': PackageRule(
    PackageRole.adapter,
    internal: {_store, _base},
  ),
  'hiflutter_store_secure': PackageRule(
    PackageRole.adapter,
    internal: {_store, _base},
  ),
  'hiflutter_store_file': PackageRule(
    PackageRole.adapter,
    internal: {_store, _base},
  ),
  // suite: the Spec table pre-installs intl (gen-l10n) for this contract.
  // Since Flutter 3.47 the Material library lives in the flutter.dev package
  // `material_ui`, so Material 3 widgets come from there.
  _suite: PackageRule(
    PackageRole.contract,
    internal: {_base, _core},
    flutter: true,
    extraThirdParty: {'intl', 'material_ui'},
  ),
  'hiflutter_suite_cached_image': PackageRule(
    PackageRole.adapter,
    internal: {_suite, _base},
  ),
  // The web page hands external links to the nav link-opener contract.
  'hiflutter_suite_webview': PackageRule(
    PackageRole.adapter,
    internal: {_suite, _base, _nav},
  ),
  // integration, umbrella, tool
  'hiflutter_riverpod': PackageRule(
    PackageRole.integration,
    internal: _contracts,
  ),
  'hiflutter': PackageRule(PackageRole.umbrella, internal: _umbrellaMembers),
  'hiflutter_tool': PackageRule(PackageRole.tool),
};

/// Whether [name] is a HiFlutter package name.
bool isHiFlutterPackage(String name) =>
    name == 'hiflutter' || name.startsWith('hiflutter_');
