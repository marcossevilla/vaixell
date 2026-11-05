import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/options/config_exception.dart';
import 'package:vaixell/src/options/option_value.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:yaml/yaml.dart';

/// Where [RuleTester.checkSource] places its file: the package directory,
/// relative to the repository root, and its `pubspec.yaml` name.
final class const TestPackage({
  /// The package directory, relative to the repository root, where `''` is
  /// the root itself.
  required final String path,

  /// The package's `pubspec.yaml` name, or `null` when it has none.
  final String? name,
}) {
  /// Creates a package at [path] named [name].
  this;
}

/// Runs rules on source and builds rules from option fixtures, the way
/// vaixell does, for rule tests.
final class const RuleTester() {
  /// Creates the tester.
  this;

  /// The findings of [rule] in [source], sorted by offset, as if [source]
  /// were the file at [path] of [package]. Paths are relative to the
  /// repository root, the form vaixell reports.
  ///
  /// Throws an [ArgumentError] when [path] isn't under the `lib/` of
  /// [package], and a [FormatException] that names each syntax error with
  /// its line and column when [source] doesn't parse.
  List<Finding> checkSource(
    Rule rule,
    String source, {
    String path = 'lib/a.dart',
    TestPackage package = const TestPackage(path: ''),
  }) {
    final lib = p.posix.join(package.path, 'lib');
    if (!p.posix.isWithin(lib, path)) {
      throw ArgumentError.value(path, 'path', 'Must be under `$lib/`');
    }
    final file = const DartFileParser().parse(
      path: path,
      content: source,
      packageRoot: package.path,
      packageName: package.name,
    );
    if (file.errors.isNotEmpty) throw _syntaxErrors(file);
    if (!rule.shouldCheck(file)) return const [];
    return [
      for (final (_, finding)
          in rule.check(file).indexed.toList()..sort(_byOffset))
        finding,
    ];
  }

  /// The rule [factory] builds from the options in the YAML file at
  /// [fixture]: the rule's entry in config, without `severity`. An empty
  /// file means the rule is enabled without options.
  ///
  /// Throws a [ConfigException] with [fixture]'s path, line and column when
  /// the options aren't valid.
  Rule createRule(RuleFactory factory, {required String fixture}) {
    final YamlNode node;
    try {
      node = loadYamlNode(
        File(fixture).readAsStringSync(),
        sourceUrl: Uri.file(fixture),
      );
    } on YamlException catch (error) {
      throw ConfigException.yaml(error, path: fixture);
    }
    final options = node.value == null
        ? const OptionValues().empty(name: factory.id, path: fixture)
        : const OptionValues().of(node, name: factory.id, path: fixture);
    return const RuleBuilder().build(factory, options);
  }

  /// Sorts by offset, keeping the rule's order for equal offsets.
  int _byOffset((int, Finding) a, (int, Finding) b) =>
      switch (a.$2.offset.compareTo(b.$2.offset)) {
        0 => a.$1.compareTo(b.$1),
        final order => order,
      };

  FormatException _syntaxErrors(DartFile file) {
    final lines = const AstBridge().resultOf(file).lineInfo;
    final errors = [
      for (final error in file.errors)
        (lines.getLocation(error.offset), error.message),
    ];
    return FormatException(
      [
        '`${file.path}` has syntax errors:',
        for (final (location, message) in errors)
          '  ${location.lineNumber}:${location.columnNumber}: $message',
      ].join('\n'),
    );
  }
}
