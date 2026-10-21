import 'package:glob/glob.dart';
import 'package:theseus_cli/src/config/presets.dart';
import 'package:theseus_cli/src/engine/violation.dart';
import 'package:yaml/yaml.dart';

/// The resolved `theseus:` configuration for a package.
class Config {
  /// Creates a config that runs the rules in [severities] and skips files
  /// that match any of the [exclude] globs, which are relative to [root].
  const new({
    required this.severities,
    this.exclude = const [],
    this.root = '',
  });

  /// Creates the config used when there is no `theseus:` section, which is
  /// the `recommended` preset.
  factory recommended() =>
      Config(severities: const Presets().all[Presets.defaultPreset]!);

  /// The severity of each enabled rule, by rule id. Rules that are missing
  /// are off.
  final Map<String, Severity> severities;

  /// Globs, relative to [root], for files that aren't checked.
  final List<Glob> exclude;

  /// The directory of the file that declared this config, relative to the
  /// repository root, or `''` for the root itself.
  final String root;

  /// Whether [path], relative to the repository root, matches one of the
  /// [exclude] globs.
  bool excludes(String path) {
    if (root.isEmpty) return exclude.any((glob) => glob.matches(path));
    if (!path.startsWith('$root/')) return false;
    final relative = path.substring(root.length + 1);
    return exclude.any((glob) => glob.matches(relative));
  }
}

/// An invalid `theseus:` configuration.
class ConfigException implements Exception {
  /// Creates an exception for a problem at [line] and [column] of the
  /// config file at [path].
  const new(
    this.message, {
    required this.path,
    required this.line,
    required this.column,
  });

  /// Creates an exception for a problem with [node] in the file at [path].
  factory at(YamlNode node, String message, {required String path}) =>
      ConfigException(
        message,
        path: path,
        line: node.span.start.line + 1,
        column: node.span.start.column + 1,
      );

  /// Creates an exception for invalid YAML in the file at [path].
  factory yaml(YamlException error, {required String path}) {
    final start = error.span?.start;
    return ConfigException(
      error.message,
      path: path,
      line: (start?.line ?? 0) + 1,
      column: (start?.column ?? 0) + 1,
    );
  }

  /// A description of the problem.
  final String message;

  /// The path of the config file.
  final String path;

  /// The 1-based line of the problem.
  final int line;

  /// The 1-based column of the problem.
  final int column;

  @override
  String toString() => '$path:$line:$column: $message';
}
