import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/config/presets.dart';
import 'package:vaixell/src/rules/parse_error.dart';
import 'package:vaixell/src/rules/registry.dart';
import 'package:vaixell/src/source/source_tree.dart';
import 'package:vaixell/src/violation/violation.dart';
import 'package:yaml/yaml.dart';

/// Loads the `vaixell:` section of `analysis_options.yaml`.
///
/// Only the `vaixell:` key is read. The analyzer's own top-level `include:`
/// is never followed, so the target repo needs no `pub get`.
class const ConfigLoader(
  /// The tree that holds the config files.
  final SourceTree tree,
) {
  /// Creates a loader that reads configs from [tree].
  this;

  /// The path of the root config file.
  static const String defaultPath = 'analysis_options.yaml';

  static const List<String> _keys = ['include', 'rules', 'exclude'];
  static const Map<String, Severity?> _severities = {
    'off': null,
    'warning': Severity.warning,
    'error': Severity.error,
  };

  /// The directory of [path], which the `exclude` globs are relative to.
  String _root(String path) => switch (p.posix.dirname(path)) {
    '.' => '',
    final dir => dir,
  };

  /// Returns the config at [path] in [tree], or [Config.recommended] when
  /// the file or its `vaixell:` key is missing.
  ///
  /// Throws a [ConfigException] when the file isn't valid YAML or the
  /// `vaixell:` section is invalid.
  Future<Config> load({String path = defaultPath}) async =>
      await loadIfPresent(path: path) ?? Config.recommended();

  /// Returns the config at [path] in [tree], or `null` when the file or its
  /// `vaixell:` key is missing. An empty `vaixell:` key counts as present.
  ///
  /// Throws a [ConfigException] when the file isn't valid YAML or the
  /// `vaixell:` section is invalid.
  Future<Config?> loadIfPresent({String path = defaultPath}) async {
    if (!await tree.exists(path)) return null;
    final root = _parse(await tree.read(path), path);
    if (root is! YamlMap || !root.containsKey('vaixell')) return null;
    final section = root.nodes['vaixell']!;
    if (section.value == null) {
      return Config(
        severities: Config.recommended().severities,
        root: _root(path),
      );
    }
    return _section(section, path);
  }

  YamlNode _parse(String content, String path) {
    try {
      return loadYamlNode(content, sourceUrl: Uri.file(path));
    } on YamlException catch (error) {
      throw ConfigException.yaml(error, path: path);
    }
  }

  Config _section(YamlNode section, String path) {
    if (section is! YamlMap) {
      throw _error(section, '`vaixell` must be a map.', path);
    }
    var presets = const [Presets.defaultPreset];
    var overrides = const <String, Severity?>{};
    var exclude = const <Glob>[];
    for (final MapEntry(:key, :value) in section.nodes.entries) {
      switch ((key as YamlNode).value) {
        case 'include':
          presets = _include(value, path);
        case 'rules':
          overrides = _rules(value, path);
        case 'exclude':
          exclude = _exclude(value, path);
        case final name:
          throw _error(
            key,
            'Unknown key `$name` under `vaixell`. '
            'Expected one of: ${_keys.join(', ')}.',
            path,
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
    return Config(severities: severities, exclude: exclude, root: _root(path));
  }

  List<String> _include(YamlNode node, String path) {
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
            path,
          ),
          _ => throw _error(
            item,
            '`include` must be a preset name or a list of preset names.',
            path,
          ),
        },
    ];
  }

  Map<String, Severity?> _rules(YamlNode node, String path) {
    if (node.value == null) return const {};
    if (node is! YamlMap) {
      throw _error(
        node,
        '`rules` must be a map of rule ids to severities.',
        path,
      );
    }
    final ids = [for (final rule in const RuleRegistry().all) rule.id];
    final result = <String, Severity?>{};
    for (final MapEntry(:key, :value) in node.nodes.entries) {
      final rule = (key as YamlNode).value;
      if (rule is! String || !ids.contains(rule)) {
        throw _error(
          key,
          'Unknown rule `$rule`. Available rules: ${ids.join(', ')}.',
          path,
        );
      }
      final severity = value.value;
      if (severity is! String || !_severities.containsKey(severity)) {
        throw _error(
          value,
          'Invalid severity `$severity` for `$rule`. '
          'Expected one of: ${_severities.keys.join(', ')}.',
          path,
        );
      }
      if (severity == 'off' && rule == const ParseErrorRule().id) {
        throw _error(value, "`$rule` can't be turned off.", path);
      }
      result[rule] = _severities[severity];
    }
    return result;
  }

  List<Glob> _exclude(YamlNode node, String path) {
    if (node.value == null) return const [];
    if (node is! YamlList) {
      throw _error(node, '`exclude` must be a list of globs.', path);
    }
    return [
      for (final item in node.nodes)
        switch (item.value) {
          final String pattern => _glob(item, pattern, path),
          _ => throw _error(item, '`exclude` must be a list of globs.', path),
        },
    ];
  }

  Glob _glob(YamlNode node, String pattern, String path) {
    try {
      return Glob(pattern, context: p.posix);
    } on FormatException catch (error) {
      throw _error(node, 'Invalid glob `$pattern`: ${error.message}', path);
    }
  }

  ConfigException _error(YamlNode node, String message, String path) =>
      ConfigException.at(node, message, path: path);
}

/// Finds the config for each package: the nearest `analysis_options.yaml`
/// with a `vaixell:` key, from the package directory up to the root.
///
/// Configs are never merged.
class const ConfigResolver(
  /// The loader that reads the config files.
  final ConfigLoader loader,
) {
  /// Creates a resolver that reads configs with [loader].
  this;

  /// Returns the config for each package in [packages], relative to the
  /// root, in order, or [Config.recommended] when no file up to the root has
  /// a `vaixell:` key. Each file is read at most once per call.
  ///
  /// Throws a [ConfigException] for the first invalid file on the way.
  Future<List<Config>> forPackages(List<String> packages) async {
    final cache = <String, Future<Config?>>{};
    return [for (final package in packages) await _forPackage(package, cache)];
  }

  Future<Config> _forPackage(
    String package,
    Map<String, Future<Config?>> cache,
  ) async {
    for (var dir = package; ; dir = _parent(dir)) {
      final path = p.posix.join(dir, ConfigLoader.defaultPath);
      final config = await cache.putIfAbsent(
        path,
        () => loader.loadIfPresent(path: path),
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
