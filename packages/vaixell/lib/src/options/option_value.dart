import 'package:vaixell/src/options/config_exception.dart';
import 'package:yaml/yaml.dart';

/// A rule's option from config, at any depth, such as the options map
/// itself, a list in it, or a string in that list.
///
/// Its readers return plain Dart values and throw a [ConfigException] with
/// the config file's path, line and column when the value doesn't match.
final class OptionValue._({
  required final YamlNode? _node,
  required final String _name,
  required final String _path,
  required final int _line,
  required final int _column,
  final String? _missing,
  final bool _isRoot = false,
  final Set<String> _hidden = const {},
}) {
  /// The value as a string.
  ///
  /// Throws a [ConfigException] when it isn't a string.
  String asString() => switch (_node) {
    YamlScalar(:final String value) => value,
    _ => throw _mismatch('a string'),
  };

  /// The value as a list.
  ///
  /// Throws a [ConfigException] when it isn't a list.
  List<OptionValue> asList() => switch (_node) {
    final YamlList list => [
      for (final (i, item) in list.nodes.indexed) _child(item, '$_name[$i]'),
    ],
    _ => throw _mismatch('a list'),
  };

  /// The value as a map from keys to values.
  ///
  /// Throws a [ConfigException] when it isn't a map, or when a key isn't a
  /// string.
  Map<String, OptionValue> asMap() => {
    for (final MapEntry(:key, :value) in _entries)
      key: _child(value, _isRoot ? key : '$_name.$key'),
  };

  /// The value at [key] of this map.
  ///
  /// A missing key gives a value whose readers throw a [ConfigException]
  /// that says it's missing, at this map's position.
  ///
  /// Throws a [ConfigException] when this isn't a map.
  OptionValue operator [](String key) =>
      asMap()[key] ??
      OptionValue._(
        node: null,
        name: _name,
        path: _path,
        line: _line,
        column: _column,
        missing: key,
      );

  /// Checks that this map has no key outside [keys].
  ///
  /// Throws a [ConfigException] at the first other key, or when this isn't a
  /// map.
  void allowOnly(Set<String> keys) {
    final map = _map;
    for (final key in map.nodes.keys.cast<YamlNode>()) {
      if (!_hidden.contains(key.value) && !keys.contains(key.value)) {
        throw const ConfigErrors().at(
          key,
          'Unknown key `${key.value}` under `$_name`. '
          'Expected one of: ${keys.join(', ')}.',
          path: _path,
        );
      }
    }
  }

  /// A [ConfigException] with [message] at this value's position, for values
  /// that read fine but aren't valid, such as a glob that doesn't parse.
  ConfigException error(String message) =>
      ConfigException(message, path: _path, line: _line, column: _column);

  YamlMap get _map => switch (_node) {
    final YamlMap map => map,
    _ => throw _mismatch('a map'),
  };

  /// The entries of this map, without the hidden keys.
  Iterable<MapEntry<String, YamlNode>> get _entries sync* {
    for (final MapEntry(:key, :value) in _map.nodes.entries) {
      final name = _key(key as YamlNode);
      if (!_hidden.contains(name)) yield MapEntry(name, value);
    }
  }

  OptionValue _child(YamlNode node, String name) => OptionValue._(
    node: node,
    name: name,
    path: _path,
    line: node.span.start.line + 1,
    column: node.span.start.column + 1,
  );

  String _key(YamlNode key) => switch (key.value) {
    final String name => name,
    _ => throw const ConfigErrors().at(
      key,
      'The keys of `$_name` must be strings.',
      path: _path,
    ),
  };

  ConfigException _mismatch(String kind) => error(switch (_missing) {
    null => '`$_name` must be $kind.',
    final key => '`$_name` needs `$key`.',
  });
}

/// Builds [OptionValue]s from config. Internal: it's never exported, so no
/// YAML type is part of the public API.
class const OptionValues() {
  /// Creates the builder.
  this;

  /// The options of the rule [name] in [node], from the file at [path],
  /// without the keys in [without], such as `severity`.
  OptionValue of(
    YamlNode node, {
    required String name,
    required String path,
    Set<String> without = const {},
  }) => OptionValue._(
    node: node,
    name: name,
    path: path,
    line: node.span.start.line + 1,
    column: node.span.start.column + 1,
    isRoot: true,
    hidden: without,
  );

  /// No options for the rule [name], enabled at [line] and [column] of the
  /// file at [path].
  OptionValue empty({
    required String name,
    required String path,
    int line = 1,
    int column = 1,
  }) => OptionValue._(
    node: YamlMap(),
    name: name,
    path: path,
    line: line,
    column: column,
    isRoot: true,
  );
}
