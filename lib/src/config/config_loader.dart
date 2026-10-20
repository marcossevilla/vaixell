import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:theseus_cli/src/config/config.dart';
import 'package:theseus_cli/src/config/presets.dart';
import 'package:theseus_cli/src/engine/violation.dart';
import 'package:theseus_cli/src/rules/parse_error.dart';
import 'package:theseus_cli/src/rules/registry.dart';
import 'package:theseus_cli/src/source/source_tree.dart';
import 'package:yaml/yaml.dart';

/// Loads the `theseus:` section of `analysis_options.yaml`.
///
/// Only the `theseus:` key is read. The analyzer's own top-level `include:`
/// is never followed, so the target repo needs no `pub get`.
class ConfigLoader {
  /// Creates a loader that reads the config at [path] in [tree].
  const new(this.tree, {this.path = 'analysis_options.yaml'});

  /// The tree that holds the config file.
  final SourceTree tree;

  /// The path of the config file in [tree].
  final String path;

  static const List<String> _keys = ['include', 'rules', 'exclude'];
  static const Map<String, Severity?> _severities = {
    'off': null,
    'warning': Severity.warning,
    'error': Severity.error,
  };

  /// Returns the config, or [Config.recommended] when the file or its
  /// `theseus:` key is missing.
  ///
  /// Throws a [ConfigException] when the file isn't valid YAML or the
  /// `theseus:` section is invalid.
  Future<Config> load() async {
    if (!await tree.exists(path)) return Config.recommended();
    final root = _parse(await tree.read(path));
    final section = root is YamlMap ? root.nodes['theseus'] : null;
    if (section == null || section.value == null) return Config.recommended();
    return _section(section);
  }

  YamlNode _parse(String content) {
    try {
      return loadYamlNode(content, sourceUrl: Uri.file(path));
    } on YamlException catch (error) {
      final start = error.span?.start;
      throw ConfigException(
        error.message,
        path: path,
        line: (start?.line ?? 0) + 1,
        column: (start?.column ?? 0) + 1,
      );
    }
  }

  Config _section(YamlNode section) {
    if (section is! YamlMap) {
      throw _error(section, '`theseus` must be a map.');
    }
    var presets = const [Presets.defaultPreset];
    var overrides = const <String, Severity?>{};
    var exclude = const <Glob>[];
    for (final MapEntry(:key, :value) in section.nodes.entries) {
      switch ((key as YamlNode).value) {
        case 'include':
          presets = _include(value);
        case 'rules':
          overrides = _rules(value);
        case 'exclude':
          exclude = _exclude(value);
        case final name:
          throw _error(
            key,
            'Unknown key `$name` under `theseus`. '
            'Expected one of: ${_keys.join(', ')}.',
          );
      }
    }

    final all = const Presets().all;
    final severities = <String, Severity>{
      for (final preset in presets) ...all[preset]!,
    };
    overrides.forEach((rule, severity) {
      if (severity == null) {
        severities.remove(rule);
      } else {
        severities[rule] = severity;
      }
    });
    severities.putIfAbsent(const ParseErrorRule().id, () => Severity.error);
    return Config(severities: severities, exclude: exclude);
  }

  List<String> _include(YamlNode node) {
    final items = node is YamlList ? node.nodes : [node];
    final available = const Presets().all.keys;
    return [
      for (final item in items)
        switch (item.value) {
          final String name when available.contains(name) => name,
          final String name => throw _error(
            item,
            'Unknown preset `$name`. '
            'Available presets: ${available.join(', ')}.',
          ),
          _ => throw _error(
            item,
            '`include` must be a preset name or a list of preset names.',
          ),
        },
    ];
  }

  Map<String, Severity?> _rules(YamlNode node) {
    if (node.value == null) return const {};
    if (node is! YamlMap) {
      throw _error(node, '`rules` must be a map of rule ids to severities.');
    }
    final ids = [for (final rule in const RuleRegistry().all) rule.id];
    final result = <String, Severity?>{};
    for (final MapEntry(:key, :value) in node.nodes.entries) {
      final rule = (key as YamlNode).value;
      if (rule is! String || !ids.contains(rule)) {
        throw _error(
          key,
          'Unknown rule `$rule`. Available rules: ${ids.join(', ')}.',
        );
      }
      final severity = value.value;
      if (severity is! String || !_severities.containsKey(severity)) {
        throw _error(
          value,
          'Invalid severity `$severity` for `$rule`. '
          'Expected one of: ${_severities.keys.join(', ')}.',
        );
      }
      if (severity == 'off' && rule == const ParseErrorRule().id) {
        throw _error(value, "`$rule` can't be turned off.");
      }
      result[rule] = _severities[severity];
    }
    return result;
  }

  List<Glob> _exclude(YamlNode node) {
    if (node.value == null) return const [];
    if (node is! YamlList) {
      throw _error(node, '`exclude` must be a list of globs.');
    }
    return [
      for (final item in node.nodes)
        switch (item.value) {
          final String pattern => _glob(item, pattern),
          _ => throw _error(item, '`exclude` must be a list of globs.'),
        },
    ];
  }

  Glob _glob(YamlNode node, String pattern) {
    try {
      return Glob(pattern, context: p.posix);
    } on FormatException catch (error) {
      throw _error(node, 'Invalid glob `$pattern`: ${error.message}');
    }
  }

  ConfigException _error(YamlNode node, String message) => ConfigException(
    message,
    path: path,
    line: node.span.start.line + 1,
    column: node.span.start.column + 1,
  );
}
