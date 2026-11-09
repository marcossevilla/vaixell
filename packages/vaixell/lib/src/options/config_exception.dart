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

/// Builds a [ConfigException] at a YAML node. Internal: it's never
/// exported, so no YAML type is part of the public API.
extension YamlNodeConfigErrors on YamlNode {
  /// An exception for a problem with this node in the file at [path].
  ConfigException configError(String message, {required String path}) =>
      ConfigException(
        message,
        path: path,
        line: span.start.line + 1,
        column: span.start.column + 1,
      );
}

/// Turns invalid YAML into a [ConfigException]. Internal: it's never
/// exported, so no YAML type is part of the public API.
extension YamlExceptionConfigErrors on YamlException {
  /// An exception for this invalid YAML in the file at [path].
  ConfigException toConfigException({required String path}) {
    final start = span?.start;
    return ConfigException(
      message,
      path: path,
      line: (start?.line ?? 0) + 1,
      column: (start?.column ?? 0) + 1,
    );
  }
}
