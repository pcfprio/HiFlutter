import '../package_rules.dart';
import '../stage.dart';
import '../workspace.dart';

/// Enforces the allowed dependency directions between HiFlutter packages.
class DepsStage implements CheckStage {
  @override
  String get id => 'deps';

  @override
  String get title => 'dependency graph (allowed table, cycles, contracts)';

  @override
  Future<StageResult> run(CheckContext context) async {
    final packages = loadWorkspace(context.root);
    final problems = <String>[];

    for (final pkg in packages.where((pkg) => pkg.publishable)) {
      final rule = packageRules[pkg.name];
      if (rule == null) {
        problems.add(
          '${pkg.name} is not in the package table '
          '(tool/src/package_rules.dart)',
        );
        continue;
      }
      for (final MapEntry(key: dep, value: spec) in pkg.dependencies.entries) {
        if (isHiFlutterPackage(dep)) {
          if (!rule.internal.contains(dep)) {
            problems.add('${pkg.name} -> $dep is not an allowed direction');
          }
        } else if (rule.role == PackageRole.contract &&
            !_contractMayUse(rule, dep, spec)) {
          problems.add(
            '${pkg.name} -> $dep: contract packages may only depend on '
            '${contractThirdParty.join(', ')}'
            '${rule.flutter ? ' and the Flutter SDK' : ''}'
            '${rule.extraThirdParty.isEmpty ? '' : ', ${rule.extraThirdParty.join(', ')}'}',
          );
        }
      }
    }

    for (final cycle in _cycles(packages)) {
      problems.add('dependency cycle: ${cycle.join(' -> ')}');
    }
    return StageResult.of(problems);
  }

  bool _contractMayUse(PackageRule rule, String dep, Object? spec) {
    if (WorkspacePackage.isSdkDependency(spec)) return rule.flutter;
    return contractThirdParty.contains(dep) ||
        rule.extraThirdParty.contains(dep);
  }

  /// Cycles among workspace members, each reported once from its
  /// alphabetically first package.
  List<List<String>> _cycles(List<WorkspacePackage> packages) {
    final graph = {
      for (final pkg in packages)
        pkg.name: [
          for (final dep in pkg.dependencies.keys)
            if (packages.any((other) => other.name == dep)) dep,
        ]..sort(),
    };
    final cycles = <List<String>>[];
    final seen = <String>{};
    for (final start in graph.keys.toList()..sort()) {
      // Depth-first search for paths returning to [start] that only visit
      // packages not yet used as a start, so each cycle is found once.
      void visit(String node, List<String> path) {
        for (final next in graph[node]!) {
          if (next == start) {
            cycles.add([...path, start]);
          } else if (!seen.contains(next) && !path.contains(next)) {
            visit(next, [...path, next]);
          }
        }
      }

      visit(start, [start]);
      seen.add(start);
    }
    return cycles;
  }
}
