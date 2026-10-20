import 'package:glob/glob.dart';
import 'package:theseus_cli/src/config/presets.dart';
import 'package:theseus_cli/src/engine/violation.dart';

/// The resolved `theseus:` configuration for a package.
class Config {
  /// Creates a config that runs the rules in [severities] and skips files
  /// that match any of the [exclude] globs.
  const new({required this.severities, this.exclude = const []});

  /// Creates the config used when there is no `theseus:` section, which is
  /// the `recommended` preset.
  factory recommended() =>
      Config(severities: const Presets().all[Presets.defaultPreset]!);

  /// The severity of each enabled rule, by rule id. Rules that are missing
  /// are off.
  final Map<String, Severity> severities;

  /// Globs, relative to the package root, for files that aren't checked.
  final List<Glob> exclude;

  /// Whether [path] matches one of the [exclude] globs.
  bool excludes(String path) => exclude.any((glob) => glob.matches(path));
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
