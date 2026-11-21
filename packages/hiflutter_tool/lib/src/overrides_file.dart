import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'lockfile.dart';
import 'tool_failure.dart';

const _modePrefix = '# hiflutter-tool:mode=';
const _beginMarker = '# BEGIN HIFLUTTER MANAGED';
const _endMarker = '# END HIFLUTTER MANAGED';

final _modeLineRegex = RegExp(r'^\s*#\s*hiflutter-tool:mode=(.+?)\s*$');
final _pinArgsRegex = RegExp(r'^pin\s+tag=(\S+)\s+url=(.+?)\s*$');
final _beginLineRegex = RegExp(r'^\s*#\s*BEGIN HIFLUTTER MANAGED\s*$');
final _endLineRegex = RegExp(r'^\s*#\s*END HIFLUTTER MANAGED\s*$');

/// Active integration mode parsed from `pubspec_overrides.yaml`.
sealed class OverridesModeState {
  const OverridesModeState();
}

/// Consumer has no tool-managed overrides (`hosted`).
final class HostedModeState extends OverridesModeState {
  /// Creates a hosted state.
  const HostedModeState();
}

/// Consumer overrides point to a sibling HiFlutter checkout (`source`).
final class SourceModeState extends OverridesModeState {
  /// Creates a source state.
  const SourceModeState();
}

/// Consumer overrides point to a pinned git tag (`pin`).
final class PinModeState extends OverridesModeState {
  /// Creates a pin state with [tag], [url], and [managedPackages].
  const PinModeState({
    required this.tag,
    required this.url,
    required this.managedPackages,
  });

  /// Pinned git tag.
  final String tag;

  /// Pinned git repository URL or path.
  final String url;

  /// Sorted package names listed inside the managed overrides section.
  final List<String> managedPackages;
}

/// Builds the header comment line for `source` mode.
String sourceModeHeader() => '${_modePrefix}source';

/// Builds the header comment line for `pin` mode.
String pinModeHeader(String tag, String url) =>
    '${_modePrefix}pin tag=$tag url=$url';

/// Reads `pubspec_overrides.yaml` under [projectDir] and identifies the current
/// integration mode and managed package set.
OverridesModeState inspectOverrides(String projectDir) {
  final file = File(p.join(projectDir, overridesFileName));
  if (!file.existsSync()) return const HostedModeState();

  final lines = _splitLines(file.readAsStringSync());
  final modeMatches = <String>[];
  for (final line in lines) {
    final match = _modeLineRegex.firstMatch(line);
    if (match != null) {
      modeMatches.add(match.group(1)!);
    }
  }

  final hasBegin = lines.any(_beginLineRegex.hasMatch);
  final hasEnd = lines.any(_endLineRegex.hasMatch);
  if (hasBegin != hasEnd) {
    throw ToolFailure(
      'Malformed $overridesFileName: unmatched managed section markers.',
    );
  }

  if (modeMatches.isEmpty) {
    if (hasBegin) {
      throw ToolFailure(
        'Malformed $overridesFileName: managed block found without mode header.',
      );
    }
    return const HostedModeState();
  }
  if (modeMatches.length > 1) {
    throw ToolFailure(
      'Malformed $overridesFileName: multiple hiflutter-tool mode headers.',
    );
  }

  final spec = modeMatches.single.trim();
  if (spec == 'source') {
    return const SourceModeState();
  }
  final pinMatch = _pinArgsRegex.firstMatch(spec);
  if (pinMatch != null) {
    final tag = pinMatch.group(1)!;
    final url = pinMatch.group(2)!;
    final managedPackages = _readManagedPackageNames(lines);
    if (managedPackages.isEmpty) {
      throw ToolFailure(
        'Malformed $overridesFileName: pin mode has no managed packages.',
      );
    }
    return PinModeState(tag: tag, url: url, managedPackages: managedPackages);
  }

  throw ToolFailure('Unrecognized hiflutter-tool mode header: "$spec".');
}

List<String> _readManagedPackageNames(List<String> lines) {
  final startIdx = lines.indexWhere(_beginLineRegex.hasMatch);
  final endIdx = lines.indexWhere(_endLineRegex.hasMatch);
  if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx) {
    throw ToolFailure(
      'Malformed $overridesFileName: missing managed block markers.',
    );
  }
  final blockLines = lines.sublist(startIdx + 1, endIdx);
  final dedented = _dedentLines(blockLines).join('\n');
  if (dedented.trim().isEmpty) return const [];

  final Object? parsed;
  try {
    parsed = loadYaml(dedented);
  } on YamlException catch (e) {
    throw ToolFailure(
      'Malformed managed block in $overridesFileName: ${e.message}',
    );
  }
  if (parsed is! YamlMap) {
    throw ToolFailure(
      'Malformed managed block in $overridesFileName: expected a mapping.',
    );
  }
  final names = [for (final key in parsed.keys) key.toString()]..sort();
  return names;
}

/// Writes or replaces tool-managed entries in `pubspec_overrides.yaml` while
/// preserving user-owned overrides and comments.
void writeManagedOverrides({
  required String projectDir,
  required String modeHeaderLine,
  required Map<String, Map<String, Object?>> managedEntries,
}) {
  final file = File(p.join(projectDir, overridesFileName));
  if (!file.existsSync()) {
    final content = _buildFreshOverrides(modeHeaderLine, managedEntries);
    _assertValidOverridesYaml(content, managedEntries.keys);
    file.writeAsStringSync(content);
    return;
  }

  final stripped = _stripToolSections(file.readAsStringSync());
  final updated = _mergeIntoStripped(stripped, modeHeaderLine, managedEntries);
  _assertValidOverridesYaml(updated, managedEntries.keys);
  file.writeAsStringSync(updated);
}

/// Removes tool-managed entries and comments from `pubspec_overrides.yaml`.
///
/// Deletes `pubspec_overrides.yaml` when no user-owned entries remain.
/// Returns `true` if the file existed and was modified or deleted.
bool removeManagedOverrides(String projectDir) {
  final file = File(p.join(projectDir, overridesFileName));
  if (!file.existsSync()) return false;

  final stripped = _stripToolSections(file.readAsStringSync());
  if (stripped.trim().isEmpty) {
    file.deleteSync();
    return true;
  }

  final Object? parsed;
  try {
    parsed = loadYaml(stripped);
  } on YamlException catch (e) {
    throw ToolFailure('Invalid $overridesFileName: ${e.message}');
  }
  if (parsed == null) {
    file.deleteSync();
    return true;
  }
  if (parsed is! YamlMap) {
    throw ToolFailure('Invalid $overridesFileName: expected a YAML mapping.');
  }

  var remaining = stripped;
  if (parsed.containsKey('dependency_overrides')) {
    final deps = parsed['dependency_overrides'];
    if (deps == null || (deps is YamlMap && deps.isEmpty)) {
      final editor = YamlEditor(remaining)..remove(['dependency_overrides']);
      remaining = editor.toString();
      final after = loadYaml(remaining);
      if (after == null || (after is YamlMap && after.isEmpty)) {
        file.deleteSync();
        return true;
      }
    }
  } else if (parsed.isEmpty) {
    file.deleteSync();
    return true;
  }

  final cleaned = '${_collapseBlankLines(remaining).trimRight()}\n';
  file.writeAsStringSync(cleaned);
  return true;
}

String _mergeIntoStripped(
  String stripped,
  String modeHeaderLine,
  Map<String, Map<String, Object?>> managedEntries,
) {
  if (stripped.trim().isEmpty) {
    return _buildFreshOverrides(modeHeaderLine, managedEntries);
  }

  final YamlNode rootNode;
  try {
    rootNode = loadYamlNode(stripped);
  } on YamlException catch (e) {
    throw ToolFailure('Invalid $overridesFileName: ${e.message}');
  }

  // Only user comments remain (no YAML mapping nodes).
  if (rootNode is YamlScalar && rootNode.value == null) {
    return _appendManagedSection(modeHeaderLine, stripped, managedEntries);
  }

  if (rootNode is! YamlMap) {
    throw ToolFailure(
      'Existing $overridesFileName must have a YAML mapping at its root.',
    );
  }

  var working = stripped;
  if (rootNode.containsKey('dependency_overrides')) {
    final deps = rootNode['dependency_overrides'];
    if (deps == null) {
      final editor = YamlEditor(working)..remove(['dependency_overrides']);
      working = editor.toString();
    } else if (deps is! YamlMap) {
      throw ToolFailure(
        'Existing $overridesFileName has non-map "dependency_overrides".',
      );
    } else {
      final editor = YamlEditor(working);
      var removedAny = false;
      for (final key in managedEntries.keys) {
        if (deps.containsKey(key)) {
          editor.remove(['dependency_overrides', key]);
          removedAny = true;
        }
      }
      if (removedAny) {
        working = editor.toString();
      }
      final afterDeps = (loadYaml(working) as YamlMap)['dependency_overrides'];
      if (afterDeps is YamlMap && afterDeps.isEmpty) {
        final cleanup = YamlEditor(working)..remove(['dependency_overrides']);
        working = cleanup.toString();
      }
    }
  }

  // Re-parse after removing empty or conflicting entries.
  final currentNode = loadYamlNode(working);
  final isEmptyDocument =
      (currentNode is YamlScalar && currentNode.value == null) ||
      (currentNode is YamlMap && currentNode.isEmpty);
  if (isEmptyDocument) {
    final withoutBraces = currentNode is YamlMap
        ? working.replaceRange(
            currentNode.span.start.offset,
            currentNode.span.end.offset,
            '',
          )
        : working;
    return _appendManagedSection(modeHeaderLine, withoutBraces, managedEntries);
  }

  final currentMap = currentNode as YamlMap;
  final depsNode = currentMap.nodes['dependency_overrides'];
  if (depsNode == null) {
    return _appendManagedSection(modeHeaderLine, working, managedEntries);
  }

  if (depsNode is! YamlMap) {
    throw ToolFailure(
      'Existing $overridesFileName has non-map "dependency_overrides".',
    );
  }

  // Convert flow-style `dependency_overrides: {a: b}` to block style so the
  // managed comment block can live cleanly inside it.
  if (depsNode.style == CollectionStyle.FLOW) {
    working = _rewriteFlowDepsAsBlock(working, depsNode);
  }

  final blockMap =
      (loadYamlNode(working) as YamlMap).nodes['dependency_overrides']!
          as YamlMap;
  final indentWidth = _childIndentWidth(blockMap);
  final indent = ' ' * indentWidth;
  final block = _renderManagedBlock(managedEntries, indent: indent);

  final endOffset = _deepestEndOffset(blockMap);
  final lineEnd = endOffset > 0 && working[endOffset - 1] == '\n'
      ? endOffset
      : _findLineEnd(working, endOffset);
  final before = working.substring(0, lineEnd);
  final after = working.substring(lineEnd);
  final separator = before.endsWith('\n') ? '' : '\n';
  final merged =
      '$modeHeaderLine\n$before$separator$block'
      '${after.isEmpty || after.startsWith('\n') ? after : '\n$after'}';
  return '${_collapseBlankLines(merged).trimRight()}\n';
}

String _rewriteFlowDepsAsBlock(String source, YamlMap depsNode) {
  final start = depsNode.span.start.offset;
  final end = depsNode.span.end.offset;
  final renderedEntries = StringBuffer();
  for (final entry in depsNode.nodes.entries) {
    final key = entry.key.toString();
    final val = entry.value;
    renderedEntries.write(_renderYamlNode(key, val, '  '));
  }
  final prefix = source.substring(0, start);
  final suffix = source.substring(end);
  final needsNewline = prefix.isNotEmpty && !prefix.endsWith('\n');
  final replacement =
      '${needsNewline ? '\n' : ''}$renderedEntries'
      '${suffix.startsWith('\n') || suffix.isEmpty ? '' : '\n'}';
  return '${prefix.replaceFirst(RegExp(r'[ \t]+$'), '')}$replacement$suffix';
}

String _renderYamlNode(String key, YamlNode value, String indent) {
  final buf = StringBuffer();
  final safeKey = _formatYamlScalar(key);
  if (value is YamlMap) {
    if (value.isEmpty) {
      buf.writeln('$indent$safeKey: {}');
    } else {
      buf.writeln('$indent$safeKey:');
      for (final child in value.nodes.entries) {
        buf.write(
          _renderYamlNode(child.key.toString(), child.value, '$indent  '),
        );
      }
    }
  } else if (value is YamlList) {
    if (value.isEmpty) {
      buf.writeln('$indent$safeKey: []');
    } else {
      buf.writeln('$indent$safeKey:');
      for (final item in value.nodes) {
        if (item is YamlScalar) {
          buf.writeln('$indent  - ${_formatYamlScalar('${item.value}')}');
        } else {
          buf.writeln('$indent  - ${item.span.text}');
        }
      }
    }
  } else {
    final scalar = (value as YamlScalar).value;
    buf.writeln('$indent$safeKey: ${_formatYamlScalar(scalar)}');
  }
  return buf.toString();
}

int _childIndentWidth(YamlMap mapNode) {
  if (mapNode.nodes.isEmpty) return 2;
  final firstKeyNode = mapNode.nodes.keys.first;
  if (firstKeyNode is YamlNode) {
    final col = firstKeyNode.span.start.column;
    if (col > 0) return col;
  }
  return 2;
}

int _deepestEndOffset(YamlNode node) {
  var current = node;
  while (true) {
    if (current is YamlMap &&
        current.style == CollectionStyle.BLOCK &&
        current.nodes.isNotEmpty) {
      current = current.nodes.values.last;
    } else if (current is YamlList &&
        current.style == CollectionStyle.BLOCK &&
        current.nodes.isNotEmpty) {
      current = current.nodes.last;
    } else {
      return current.span.end.offset;
    }
  }
}

int _findLineEnd(String text, int offset) {
  var index = offset;
  while (index < text.length && text[index] != '\n') {
    index++;
  }
  if (index < text.length && text[index] == '\n') {
    index++;
  }
  return index;
}

String _appendManagedSection(
  String modeHeaderLine,
  String prefix,
  Map<String, Map<String, Object?>> managedEntries,
) {
  final body = _collapseBlankLines(prefix).trim();
  final block = _renderManagedBlock(managedEntries, indent: '  ');
  if (body.isEmpty) {
    return '$modeHeaderLine\ndependency_overrides:\n$block\n';
  }
  return '$modeHeaderLine\n$body\ndependency_overrides:\n$block\n';
}

String _buildFreshOverrides(
  String modeHeaderLine,
  Map<String, Map<String, Object?>> managedEntries,
) {
  final block = _renderManagedBlock(managedEntries, indent: '  ');
  return '$modeHeaderLine\ndependency_overrides:\n$block\n';
}

String _renderManagedBlock(
  Map<String, Map<String, Object?>> managedEntries, {
  required String indent,
}) {
  final buf = StringBuffer()..writeln('$indent$_beginMarker');
  final sortedKeys = managedEntries.keys.toList()..sort();
  for (final pkg in sortedKeys) {
    _writeMapEntry(buf, pkg, managedEntries[pkg]!, indent);
  }
  buf.write('$indent$_endMarker');
  return buf.toString();
}

void _writeMapEntry(
  StringBuffer buf,
  String key,
  Map<String, Object?> value,
  String indent,
) {
  buf.writeln('$indent${_formatYamlScalar(key)}:');
  for (final entry in value.entries) {
    final childIndent = '$indent  ';
    final childValue = entry.value;
    if (childValue is Map<String, Object?>) {
      _writeMapEntry(buf, entry.key, childValue, childIndent);
    } else if (childValue != null) {
      buf.writeln(
        '$childIndent${_formatYamlScalar(entry.key)}: '
        '${_formatYamlScalar(childValue)}',
      );
    }
  }
}

String _formatYamlScalar(Object? value) {
  if (value is bool || value is num) return '$value';
  final text = '$value';
  if (text.isEmpty) return "''";
  const needsQuotePattern = r'''[\s:#{}\[\],&*?|<>=!%@`'"\\]''';
  final startsSpecial = text.startsWith('-') || text.startsWith('?');
  if (startsSpecial ||
      RegExp(needsQuotePattern).hasMatch(text) ||
      text == 'null' ||
      text == 'true' ||
      text == 'false') {
    return "'${text.replaceAll("'", "''")}'";
  }
  return text;
}

String _stripToolSections(String raw) {
  final lines = _splitLines(raw);
  final out = <String>[];
  var inManaged = false;

  for (final line in lines) {
    if (_beginLineRegex.hasMatch(line)) {
      if (inManaged) {
        throw ToolFailure(
          'Malformed $overridesFileName: nested $_beginMarker marker.',
        );
      }
      inManaged = true;
      continue;
    }
    if (_endLineRegex.hasMatch(line)) {
      if (!inManaged) {
        throw ToolFailure(
          'Malformed $overridesFileName: unmatched $_endMarker marker.',
        );
      }
      inManaged = false;
      continue;
    }
    if (inManaged) continue;
    if (_modeLineRegex.hasMatch(line)) continue;
    out.add(line);
  }

  if (inManaged) {
    throw ToolFailure(
      'Malformed $overridesFileName: missing $_endMarker marker.',
    );
  }

  return _collapseBlankLines(out.join('\n'));
}

List<String> _splitLines(String text) {
  final normalized = text.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

List<String> _dedentLines(List<String> lines) {
  int? minIndent;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final leading = line.length - line.trimLeft().length;
    if (minIndent == null || leading < minIndent) {
      minIndent = leading;
    }
  }
  if (minIndent == null || minIndent == 0) return lines;
  return [
    for (final line in lines)
      line.length >= minIndent ? line.substring(minIndent) : line,
  ];
}

String _collapseBlankLines(String text) {
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final out = <String>[];
  var blankRun = 0;
  for (final line in lines) {
    if (line.trim().isEmpty) {
      if (out.isEmpty) continue;
      blankRun++;
      if (blankRun > 1) continue;
      out.add('');
    } else {
      blankRun = 0;
      out.add(line);
    }
  }
  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
  }
  return out.isEmpty ? '' : '${out.join('\n')}\n';
}

void _assertValidOverridesYaml(
  String content,
  Iterable<String> expectedManagedKeys,
) {
  final Object? parsed;
  try {
    parsed = loadYaml(content);
  } on YamlException catch (e) {
    throw ToolFailure('Generated invalid $overridesFileName: ${e.message}');
  }
  if (parsed is! YamlMap) {
    throw ToolFailure('Generated $overridesFileName is not a YAML mapping.');
  }
  final deps = parsed['dependency_overrides'];
  if (deps is! YamlMap) {
    throw ToolFailure(
      'Generated $overridesFileName lacks "dependency_overrides".',
    );
  }
  for (final key in expectedManagedKeys) {
    if (!deps.containsKey(key)) {
      throw ToolFailure(
        'Generated $overridesFileName is missing managed entry "$key".',
      );
    }
  }
}
