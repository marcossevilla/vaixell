import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/options/config_exception.dart';
import 'package:vaixell/src/options/option_value.dart';
import 'package:vaixell/src/rules/rule.dart';
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

  /// The rules that configs can enable, in reporting order.
  final RuleSet rules,
) {
  /// Creates a loader that reads configs from [tree] and configures
  /// [rules]. Config can only name these rules and `parse-error`.
  this;

  /// The path of the root config file.
  static const String defaultPath = 'analysis_options.yaml';

  /// Returns the config at [path] in [tree], or the [Config.recommended] one
  /// for [rules] when the file or its `vaixell:` key is missing.
  ///
  /// Throws a [ConfigException] when the file isn't valid YAML or the
  /// `vaixell:` section is invalid.
  Future<Config> load({String path = defaultPath}) async =>
      await loadIfPresent(path: path) ?? Config.recommended(rules);

  /// Returns the config at [path] in [tree], or `null` when the file or its
  /// `vaixell:` key is missing. An empty `vaixell:` key counts as present.
  ///
  /// Throws a [ConfigException] when the file isn't valid YAML or the
  /// `vaixell:` section is invalid.
  Future<Config?> loadIfPresent({String path = defaultPath}) async {
    if (!await tree.exists(path)) return null;
    return _ConfigFile.parse(path, await tree.read(path)).config(rules);
  }
}

/// One config file at [path], with its `vaixell:` [section].
final class _ConfigFile(
  /// The path of the file, for error locations and the exclude root.
  final String path,

  /// The `vaixell:` section, or `null` when the file has no `vaixell:` key.
  final YamlNode? section,
) {
  /// Parses [content] as the config file at [path].
  ///
  /// Throws a [ConfigException] when [content] isn't valid YAML.
  factory parse(String path, String content) {
    final YamlNode root;
    try {
      root = loadYamlNode(content, sourceUrl: Uri.file(path));
    } on YamlException catch (error) {
      throw error.toConfigException(path: path);
    }
    return _ConfigFile(path, root is YamlMap ? root.nodes['vaixell'] : null);
  }

  static const List<String> _keys = ['include', 'rules', 'exclude'];
  static const String _recommended = 'recommended';

  /// The directory of [path], which the `exclude` globs are relative to.
  String get _root => p.posix.dirname(path).asTreePath;

  /// The config that the [section] sets for [rules], or `null` when there's
  /// no section. An empty section enables the recommended rules.
  ///
  /// Throws a [ConfigException] when the section is invalid.
  Config? config(RuleSet rules) => switch (section) {
    null => null,
    final section when section.value == null => _configure(rules, section),
    final YamlMap section => _section(rules, section),
    final section => throw section.configError(
      '`vaixell` must be a map.',
      path: path,
    ),
  };

  Config _section(RuleSet rules, YamlMap section) {
    var presets = const [_recommended];
    var overrides = const <String, _RuleConfig>{};
    var exclude = const <Glob>[];
    for (final MapEntry(:key, :value) in section.nodes.entries) {
      switch ((key as YamlNode).value) {
        case 'include':
          presets = _include(value);
        case 'rules':
          overrides = _rules(rules, value);
        case 'exclude':
          exclude = _exclude(value);
        case final name:
          throw key.configError(
            'Unknown key `$name` under `vaixell`. '
            'Expected one of: ${_keys.join(', ')}.',
            path: path,
          );
      }
    }

    return _configure(
      rules,
      section,
      recommended: presets.isNotEmpty,
      overrides: overrides,
      exclude: exclude,
    );
  }

  /// The config that enables the recommended rules, when [recommended], and
  /// applies [overrides]. Rules without options in config get none, at
  /// [section].
  Config _configure(
    RuleSet rules,
    YamlNode section, {
    bool recommended = true,
    Map<String, _RuleConfig> overrides = const {},
    List<Glob> exclude = const [],
  }) => Config.configure(
    rules,
    severities: {
      for (final MapEntry(key: id, value: override) in overrides.entries)
        id: override.severityFor(rules[id]),
    },
    options: (id) =>
        overrides[id]?.options(path) ??
        YamlOptionValue.empty(name: id, path: path, at: section),
    recommended: recommended,
    exclude: exclude,
    root: _root,
  );

  List<String> _include(YamlNode node) {
    final items = node is YamlList ? node.nodes : [node];
    const available = [_recommended];
    return [
      for (final item in items)
        switch (item.value) {
          final String name when available.contains(name) => name,
          final String name => throw item.configError(
            'Unknown preset `$name`. '
            'Available presets: ${available.join(', ')}.',
            path: path,
          ),
          _ => throw item.configError(
            '`include` must be a preset name or a list of preset names.',
            path: path,
          ),
        },
    ];
  }

  Map<String, _RuleConfig> _rules(RuleSet rules, YamlNode node) {
    if (node.value == null) return const {};
    if (node is! YamlMap) {
      throw node.configError(
        '`rules` must be a map of rule ids to severities.',
        path: path,
      );
    }
    return {
      for (final MapEntry(:key, :value) in node.nodes.entries)
        _id(key as YamlNode, rules.configIds): _rule(
          key,
          value,
          takesOptions: rules[key.value as String] is RuleFactory,
        ),
    };
  }

  String _id(YamlNode key, List<String> ids) => switch (key.value) {
    final String id when ids.contains(id) => id,
    final id => throw key.configError(
      'Unknown rule `$id`. Available rules: ${ids.join(', ')}.',
      path: path,
    ),
  };

  /// The config of the rule at [key]: `id: severity`, or
  /// `id: {severity: …, <options>}` when it [takesOptions].
  _RuleConfig _rule(
    YamlNode key,
    YamlNode value, {
    required bool takesOptions,
  }) {
    final id = key.value as String;
    if (value is! YamlMap) {
      return _RuleConfig(key, _severityName(value, id), null);
    }
    for (final option in value.nodes.keys.cast<YamlNode>()) {
      if (option.value != 'severity' && !takesOptions) {
        throw option.configError('`$id` takes no options.', path: path);
      }
    }
    return _RuleConfig(key, switch (value.nodes['severity']) {
      final severity? => _severityName(severity, id),
      null => null,
    }, value);
  }

  /// The severity name in [node], for the rule [id].
  String _severityName(YamlNode node, String id) {
    final severity = node.value;
    if (severity is! String || !_RuleConfig.severities.containsKey(severity)) {
      throw node.configError(
        'Invalid severity `$severity` for `$id`. '
        'Expected one of: ${_RuleConfig.severities.keys.join(', ')}.',
        path: path,
      );
    }
    if (severity == 'off' && id == Config.parseErrorId) {
      throw node.configError("`$id` can't be turned off.", path: path);
    }
    return severity;
  }

  List<Glob> _exclude(YamlNode node) {
    if (node.value == null) return const [];
    if (node is! YamlList) {
      throw node.configError('`exclude` must be a list of globs.', path: path);
    }
    return [
      for (final item in node.nodes)
        switch (item.value) {
          final String pattern => _glob(item, pattern),
          _ => throw item.configError(
            '`exclude` must be a list of globs.',
            path: path,
          ),
        },
    ];
  }

  Glob _glob(YamlNode node, String pattern) {
    try {
      return Glob(pattern, context: p.posix);
    } on FormatException catch (error) {
      throw node.configError(
        'Invalid glob `$pattern`: ${error.message}',
        path: path,
      );
    }
  }
}

/// How config sets one rule under `rules:`.
class const _RuleConfig(
  /// The rule's key, where it's enabled.
  final YamlNode key,

  /// The severity name, or `null` when the long form leaves it out.
  final String? severityName,

  /// The long form's map, or `null` for the short form.
  final YamlMap? entry,
) {
  static const Map<String, Severity?> severities = {
    'off': null,
    'warning': Severity.warning,
    'error': Severity.error,
  };

  /// The severity, the default of [rule] when config leaves it out, or
  /// `null` when it's off. `parse-error` has no [rule], and is an error by
  /// default.
  Severity? severityFor(RuleEntry? rule) => switch (severityName) {
    null => rule?.defaultSeverity ?? Severity.error,
    final name => severities[name],
  };

  /// The rule's options from the file at [path], without `severity`: the
  /// long form's map, or none at its key for the short form.
  OptionValue options(String path) => switch (entry) {
    final entry? => YamlOptionValue.of(
      entry,
      name: key.value as String,
      path: path,
      without: const {'severity'},
    ),
    null => YamlOptionValue.empty(
      name: key.value as String,
      path: path,
      at: key,
    ),
  };
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

  /// Returns the config for each package directory in [packages], relative
  /// to the root, keyed by directory: the nearest one, or the
  /// [Config.recommended] one for the loader's rules when no file up to the
  /// root has a `vaixell:` key. Each file is read at most once per call.
  ///
  /// Throws a [ConfigException] for the first invalid file on the way.
  Future<Map<String, Config>> forPackages(Iterable<String> packages) async {
    final cache = <String, Future<Config?>>{};
    return {
      for (final package in packages)
        package: await _forPackage(package, cache),
    };
  }

  Future<Config> _forPackage(
    String package,
    Map<String, Future<Config?>> cache,
  ) async {
    for (var dir = package; ; dir = p.posix.dirname(dir).asTreePath) {
      final path = p.posix.join(dir, ConfigLoader.defaultPath);
      final config = await cache.putIfAbsent(
        path,
        () => loader.loadIfPresent(path: path),
      );
      if (config != null) return config;
      if (dir.isEmpty) return Config.recommended(loader.rules);
    }
  }
}
