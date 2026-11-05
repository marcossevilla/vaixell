import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/config/config.dart';
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
  final List<RuleEntry> rules,
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
    return _ConfigFile(path, rules).parse(await tree.read(path));
  }
}

/// The `vaixell:` section of one config file at [path].
class const _ConfigFile(
  /// The path of the file, for error locations and the exclude root.
  final String path,

  /// The rules config can enable.
  final List<RuleEntry> entries,
) {
  static const List<String> _keys = ['include', 'rules', 'exclude'];
  static const String _recommended = 'recommended';

  /// The directory of [path], which the `exclude` globs are relative to.
  String get _root => switch (p.posix.dirname(path)) {
    '.' => '',
    final dir => dir,
  };

  /// Returns the config in [content], or `null` when its `vaixell:` key is
  /// missing.
  Config? parse(String content) {
    final root = _yaml(content);
    if (root is! YamlMap || !root.containsKey('vaixell')) return null;
    final section = root.nodes['vaixell']!;
    if (section.value == null) return _config(section);
    return _section(section);
  }

  YamlNode _yaml(String content) {
    try {
      return loadYamlNode(content, sourceUrl: Uri.file(path));
    } on YamlException catch (error) {
      throw const ConfigErrors().yaml(error, path: path);
    }
  }

  Config _section(YamlNode section) {
    if (section is! YamlMap) {
      throw _error(section, '`vaixell` must be a map.');
    }
    var presets = const [_recommended];
    var overrides = const <String, _RuleConfig>{};
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

    return _config(
      section,
      recommended: presets.isNotEmpty,
      overrides: overrides,
      exclude: exclude,
    );
  }

  /// The config that enables the recommended rules, when [recommended], and
  /// applies [overrides]. Rules without options in config get none, at [at].
  Config _config(
    YamlNode at, {
    bool recommended = true,
    Map<String, _RuleConfig> overrides = const {},
    List<Glob> exclude = const [],
  }) => Config(
    rules: [
      for (final entry in entries)
        if (_severity(entry, overrides[entry.id], recommended: recommended)
            case final severity?)
          (
            const RuleBuilder().build(
              entry,
              overrides[entry.id]?.options(path) ?? _noOptions(entry.id, at),
            ),
            severity,
          ),
    ],
    parseErrorSeverity:
        overrides[Config.parseErrorId]?.severity(Severity.error) ??
        Severity.error,
    exclude: exclude,
    root: _root,
  );

  /// The severity of [entry] with [override], or `null` when it's off.
  Severity? _severity(
    RuleEntry entry,
    _RuleConfig? override, {
    required bool recommended,
  }) => switch (override) {
    final override? => override.severity(entry.defaultSeverity),
    null when recommended && entry.recommended => entry.defaultSeverity,
    null => null,
  };

  OptionValue _noOptions(String rule, YamlNode at) =>
      const OptionValues().empty(
        name: rule,
        path: path,
        line: at.span.start.line + 1,
        column: at.span.start.column + 1,
      );

  List<String> _include(YamlNode node) {
    final items = node is YamlList ? node.nodes : [node];
    const available = [_recommended];
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

  Map<String, _RuleConfig> _rules(YamlNode node) {
    if (node.value == null) return const {};
    if (node is! YamlMap) {
      throw _error(node, '`rules` must be a map of rule ids to severities.');
    }
    final ids = [Config.parseErrorId, for (final entry in entries) entry.id];
    return {
      for (final MapEntry(:key, :value) in node.nodes.entries)
        _id(key as YamlNode, ids): _rule(key, value),
    };
  }

  String _id(YamlNode key, List<String> ids) => switch (key.value) {
    final String id when ids.contains(id) => id,
    final id => throw _error(
      key,
      'Unknown rule `$id`. Available rules: ${ids.join(', ')}.',
    ),
  };

  /// The config of the rule at [key]: `id: severity`, or
  /// `id: {severity: …, <options>}`.
  _RuleConfig _rule(YamlNode key, YamlNode value) {
    final id = key.value as String;
    if (value is! YamlMap) {
      return _RuleConfig(key, _severityName(value, id), null);
    }
    final takesOptions = entries.any(
      (entry) => entry is RuleFactory && entry.id == id,
    );
    for (final option in value.nodes.keys.cast<YamlNode>()) {
      if (option.value != 'severity' && !takesOptions) {
        throw _error(option, '`$id` takes no options.');
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
      throw _error(
        node,
        'Invalid severity `$severity` for `$id`. '
        'Expected one of: ${_RuleConfig.severities.keys.join(', ')}.',
      );
    }
    if (severity == 'off' && id == Config.parseErrorId) {
      throw _error(node, "`$id` can't be turned off.");
    }
    return severity;
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
      const ConfigErrors().at(node, message, path: path);
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

  /// The severity, [byDefault] when config leaves it out, or `null` when the
  /// rule is off.
  Severity? severity(Severity byDefault) => switch (severityName) {
    null => byDefault,
    final name => severities[name],
  };

  /// The rule's options in the config file at [path], without `severity`.
  OptionValue options(String path) => switch (entry) {
    final entry? => const OptionValues().of(
      entry,
      name: key.value as String,
      path: path,
      without: const {'severity'},
    ),
    null => const OptionValues().empty(
      name: key.value as String,
      path: path,
      line: key.span.start.line + 1,
      column: key.span.start.column + 1,
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

  /// Returns the config for each package in [packages], relative to the
  /// root, in order, or the [Config.recommended] one for the loader's rules
  /// when no file up to the root has a `vaixell:` key. Each file is read at
  /// most once per call.
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
      if (dir.isEmpty) return Config.recommended(loader.rules);
    }
  }

  String _parent(String dir) => switch (p.posix.dirname(dir)) {
    '.' => '',
    final parent => parent,
  };
}
