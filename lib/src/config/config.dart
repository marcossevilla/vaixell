import 'package:glob/glob.dart';
import 'package:vaixell/src/config/presets.dart';
import 'package:vaixell/src/engine/violation.dart';
import 'package:yaml/yaml.dart';

/// The resolved `vaixell:` configuration for a package.
class const Config({
  /// The severity of each enabled rule, by rule id.
  ///
  /// Rules that are missing are off.
  required final Map<String, Severity> severities,

  /// Globs, relative to [root], for files that aren't checked.
  final List<Glob> exclude = const [],

  /// The directory of the file that declared this config, relative to the
  /// repository root, or `''` for the root itself.
  final String root = '',
}) {
  /// Creates a config that runs the rules in [severities] and skips files
  /// that match any of the [exclude] globs, which are relative to [root].
  this;

  /// Creates the config used when there is no `vaixell:` section, which is
  /// the `recommended` preset.
  factory recommended() =>
      Config(severities: const Presets().all[Presets.defaultPreset]!);

  /// Whether [path], relative to the repository root, matches one of the
  /// [exclude] globs.
  bool excludes(String path) {
    if (root.isEmpty) return exclude.any((glob) => glob.matches(path));
    if (!path.startsWith('$root/')) return false;
    final relative = path.substring(root.length + 1);
    return exclude.any((glob) => glob.matches(relative));
  }
}

/// An invalid `vaixell:` configuration.
class const ConfigException(
  /// A description of the problem.
  final String message, {

  /// The path of the config file.
  required final String path,

  /// The 1-based line of the problem.
  required final int line,

  /// The 1-based column of the problem.
  required final int column,
}) implements Exception {
  /// Creates an exception for a problem at [line] and [column] of the
  /// config file at [path].
  this;

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

  @override
  String toString() => '$path:$line:$column: $message';
}
