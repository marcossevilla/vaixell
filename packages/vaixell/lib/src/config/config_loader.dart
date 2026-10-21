import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/config/presets.dart';
import 'package:vaixell/src/engine/violation.dart';
import 'package:vaixell/src/rules/parse_error.dart';
import 'package:vaixell/src/rules/registry.dart';
import 'package:vaixell/src/source/source_tree.dart';
import 'package:yaml/yaml.dart';

/// Loads the `vaixell:` section of `analysis_options.yaml`.
///
/// Only the `vaixell:` key is read. The analyzer's own top-level `include:`
/// is never followed, so the target repo needs no `pub get`.
class const ConfigLoader(
  /// The tree that holds the config file.
  final SourceTree tree, {

  /// The path of the config file in [tree].
  final String path = 'analysis_options.yaml',
}) {
  /// Creates a loader that reads the config at [path] in [tree].
  this;

  static const List<String> _keys = ['include', 'rules', 'exclude'];
  static const Map<String, Severity?> _severities = {
    'off': null,
    'warning': Severity.warning,
    'error': Severity.error,
  };

  /// The directory of [path], which the `exclude` globs are relative to.
  String get _root => switch (p.posix.dirname(path)) {
    '.' => '',
    final dir => dir,
  };

  /// Returns the config, or [Config.recommended] when the file or its
  /// `vaixell:` key is missing.
  ///
  /// Throws a [ConfigException] when the file isn't valid YAML or the
  /// `vaixell:` section is invalid.
  Future<Config> load() async => await loadIfPresent() ?? Config.recommended();

  /// Returns the config, or `null` when the file or its `vaixell:` key is
  /// missing. An empty `vaixell:` key counts as present.
  ///
  /// Throws a [ConfigException] when the file isn't valid YAML or the
  /// `vaixell:` section is invalid.
  Future<Config?> loadIfPresent() async {
    if (!await tree.exists(path)) return null;
    final root = _parse(await tree.read(path));
    if (root is! YamlMap || !root.containsKey('vaixell')) return null;
    final section = root.nodes['vaixell']!;
    if (section.value == null) {
      return Config(severities: Config.recommended().severities, root: _root);
    }
    return _section(section);
  }

  YamlNode _parse(String content) {
    try {
      return loadYamlNode(content, sourceUrl: Uri.file(path));
    } on YamlException catch (error) {
      throw ConfigException.yaml(error, path: path);
    }
  }

  Config _section(YamlNode section) {
    if (section is! YamlMap) {
      throw _error(section, '`vaixell` must be a map.');
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
            'Unknown key `$name` under `vaixell`. '
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
    return Config(severities: severities, exclude: exclude, root: _root);
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

  ConfigException _error(YamlNode node, String message) =>
      ConfigException.at(node, message, path: path);
}

/// Finds the config for each package: the nearest `analysis_options.yaml`
/// with a `vaixell:` key, from the package directory up to the root.
///
/// Configs are never merged. Each file is read at most once.
class ConfigResolver(
  /// The tree that holds the config files.
  final SourceTree tree,
) {
  /// Creates a resolver that reads configs from [tree].
  this;

  final Map<String, Future<Config?>> _cache = {};

  /// Returns the config for the package at [package], relative to the root,
  /// or [Config.recommended] when no file up to the root has a `vaixell:`
  /// key.
  ///
  /// Throws a [ConfigException] for the first invalid file on the way.
  Future<Config> forPackage(String package) async {
    for (var dir = package; ; dir = _parent(dir)) {
      final path = p.posix.join(dir, 'analysis_options.yaml');
      final config = await _cache.putIfAbsent(
        path,
        () => ConfigLoader(tree, path: path).loadIfPresent(),
      );
      if (config != null) return config;
      if (dir.isEmpty) return Config.recommended();
    }
  }

  String _parent(String dir) => switch (p.posix.dirname(dir)) {
    '.' => '',
    final parent => parent,
  };
}
