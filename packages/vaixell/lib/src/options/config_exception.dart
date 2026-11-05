import 'package:yaml/yaml.dart';

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

  @override
  String toString() => '$path:$line:$column: $message';
}

/// Builds [ConfigException]s from YAML. Internal: it's never exported, so
/// no YAML type is part of the public API.
class const ConfigErrors() {
  /// Creates the builder.
  this;

  /// An exception for a problem with [node] in the file at [path].
  ConfigException at(YamlNode node, String message, {required String path}) =>
      ConfigException(
        message,
        path: path,
        line: node.span.start.line + 1,
        column: node.span.start.column + 1,
      );

  /// An exception for invalid YAML in the file at [path].
  ConfigException yaml(YamlException error, {required String path}) {
    final start = error.span?.start;
    return ConfigException(
      error.message,
      path: path,
      line: (start?.line ?? 0) + 1,
      column: (start?.column ?? 0) + 1,
    );
  }
}
