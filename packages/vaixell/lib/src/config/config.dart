import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/options/option_value.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

export 'package:vaixell/src/options/config_exception.dart';

/// A rule that a [Config] enables, with the severity of its violations.
final class const ConfiguredRule(
  /// The rule, built with the config's options.
  final Rule rule,

  /// The severity of the rule's violations.
  final Severity severity,
) {
  /// Creates the [rule] that config enables at [severity].
  this;
}

/// The resolved `vaixell:` configuration for a package.
class const Config({
  /// The enabled rules, each with its severity, in reporting order.
  ///
  /// Rules that are missing are off.
  required final List<ConfiguredRule> rules,

  /// The severity of syntax errors, which are always reported.
  final Severity parseErrorSeverity = Severity.error,

  /// Globs, relative to [root], for files that aren't checked.
  final List<Glob> exclude = const [],

  /// The directory of the file that declared this config, relative to the
  /// repository root, or `''` for the root itself.
  final String root = '',
}) {
  /// Creates a config that runs [rules] and skips files that match any of
  /// the [exclude] globs, which are relative to [root].
  this;

  /// Creates the config that runs each of [rules] at its severity in
  /// [severities], or else, when [recommended], at its default severity if
  /// it's [RuleEntry.recommended]. Each rule is built with the [options] for
  /// its id, once.
  ///
  /// [severities] maps the ids that config sets, including [parseErrorId],
  /// to their severity, or to `null` when they're off.
  factory configure(
    RuleSet rules, {
    required OptionValue Function(String id) options,
    Map<String, Severity?> severities = const {},
    bool recommended = true,
    List<Glob> exclude = const [],
    String root = '',
  }) {
    Severity? severityOf(RuleEntry entry) =>
        switch (severities.containsKey(entry.id)) {
          true => severities[entry.id],
          false when recommended && entry.recommended => entry.defaultSeverity,
          false => null,
        };
    return Config(
      rules: [
        for (final entry in rules.entries)
          if (severityOf(entry) case final severity?)
            ConfiguredRule(entry.build(options(entry.id)), severity),
      ],
      parseErrorSeverity: severities[parseErrorId] ?? Severity.error,
      exclude: exclude,
      root: root,
    );
  }

  /// Creates the `recommended` config for the [rules] a caller runs: every
  /// rule at its default severity, except those that aren't
  /// [RuleEntry.recommended].
  ///
  /// It's the config used when there's no config file. Factories build
  /// their rules without options, and report errors at the start of
  /// [root]'s `analysis_options.yaml`, where options would go.
  factory recommended(RuleSet rules, {String root = ''}) => Config.configure(
    rules,
    options: (id) => YamlOptionValue.empty(
      name: id,
      path: p.posix.join(root, 'analysis_options.yaml'),
    ),
    root: root,
  );

  /// The id of the syntax errors the engine reports. It isn't a rule, but
  /// its severity is set under `rules:` like one.
  static const String parseErrorId = 'parse-error';

  /// Whether [path], relative to the repository root, matches one of the
  /// [exclude] globs.
  bool excludes(String path) {
    if (root.isEmpty) return exclude.any((glob) => glob.matches(path));
    if (!path.startsWith('$root/')) return false;
    final relative = path.substring(root.length + 1);
    return exclude.any((glob) => glob.matches(relative));
  }
}

/// The rules a caller runs, each with its own id, in reporting order.
final class RuleSet(Iterable<RuleEntry> rules) {
  /// Creates the set of [rules].
  ///
  /// Throws an [ArgumentError] when two [rules] share an id, or one is
  /// [Config.parseErrorId], since config and violation ids couldn't tell
  /// them apart.
  this {
    final seen = <String>{};
    for (final RuleEntry(:id) in entries) {
      if (id == Config.parseErrorId) {
        throw ArgumentError.value(
          entries,
          'rules',
          '`$id` is reported by the engine, not by a rule.',
        );
      }
      if (!seen.add(id)) {
        throw ArgumentError.value(
          entries,
          'rules',
          'Two rules have the id `$id`.',
        );
      }
    }
  }

  /// The rules, in reporting order.
  final List<RuleEntry> entries = List.unmodifiable(rules);

  /// The ids that config can name: [Config.parseErrorId], then the id of
  /// each rule, in order.
  List<String> get configIds => [
    Config.parseErrorId,
    for (final entry in entries) entry.id,
  ];

  /// The rule with [id], or `null` when there's none.
  RuleEntry? operator [](String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}
