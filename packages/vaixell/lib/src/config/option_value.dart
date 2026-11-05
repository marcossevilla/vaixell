import 'package:vaixell/src/config/config.dart';
import 'package:yaml/yaml.dart';

/// A rule's option from config, at any depth, such as the options map
/// itself, a list in it, or a string in that list.
///
/// Its readers return plain Dart values and throw a [ConfigException] with
/// the config file's path, line and column when the value doesn't match.
final class OptionValue._({
  required final YamlNode? _node,
  required final YamlNode _at,
  required final String _name,
  required final String _path,
  final String? _missing,
  final bool _isRoot = false,
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
      for (final (i, item) in list.nodes.indexed)
        OptionValue._(node: item, at: item, name: '$_name[$i]', path: _path),
    ],
    _ => throw _mismatch('a list'),
  };

  /// The value as a map from keys to values.
  ///
  /// Throws a [ConfigException] when it isn't a map, or when a key isn't a
  /// string.
  Map<String, OptionValue> asMap() => switch (_node) {
    final YamlMap map => {
      for (final MapEntry(:key, :value) in map.nodes.entries)
        _key(key as YamlNode): OptionValue._(
          node: value,
          at: value,
          name: _isRoot ? _key(key) : '$_name.${_key(key)}',
          path: _path,
        ),
    },
    _ => throw _mismatch('a map'),
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
        at: _at,
        name: _name,
        path: _path,
        missing: key,
      );

  /// Checks that this map has no key outside [keys].
  ///
  /// Throws a [ConfigException] at the first other key, or when this isn't a
  /// map.
  void allowOnly(Set<String> keys) {
    asMap();
    for (final key in (_node! as YamlMap).nodes.keys.cast<YamlNode>()) {
      if (!keys.contains(key.value)) {
        throw ConfigException.at(
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
      ConfigException.at(_at, message, path: _path);

  String _key(YamlNode key) => switch (key.value) {
    final String name => name,
    _ => throw ConfigException.at(
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

  /// The options of the rule [name] in [node], from the file at [path].
  OptionValue of(YamlNode node, {required String name, required String path}) =>
      OptionValue._(node: node, at: node, name: name, path: path, isRoot: true);

  /// No options for the rule [name], enabled at [at] in the file at [path].
  OptionValue empty(
    YamlNode at, {
    required String name,
    required String path,
  }) => OptionValue._(
    node: YamlMap(),
    at: at,
    name: name,
    path: path,
    isRoot: true,
  );
}
