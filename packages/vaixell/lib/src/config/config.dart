import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/options/option_value.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

export 'package:vaixell/src/options/config_exception.dart';

/// The resolved `vaixell:` configuration for a package.
class const Config({
  /// The enabled rules, each with its severity, in reporting order.
  ///
  /// Rules that are missing are off.
  required final List<(Rule, Severity)> rules,

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

  /// Creates the `recommended` config for the [entries] a caller runs: every
  /// entry at its default severity, except those that aren't
  /// [RuleEntry.recommended].
  ///
  /// It's the config used when there's no config file. Factories build
  /// their rules without options, and report errors at the start of
  /// [root]'s `analysis_options.yaml`, where options would go.
  ///
  /// Throws an [ArgumentError] when two [entries] share an id, or one is
  /// `parse-error`.
  factory recommended(List<RuleEntry> entries, {String root = ''}) {
    const RuleIds().check(entries);
    return Config(
      rules: [
        for (final entry in entries)
          if (entry.recommended)
            (
              const RuleBuilder().build(
                entry,
                const OptionValues().empty(
                  name: entry.id,
                  path: p.posix.join(root, 'analysis_options.yaml'),
                ),
              ),
              entry.defaultSeverity,
            ),
      ],
      root: root,
    );
  }

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

/// Checks the ids of the rules a caller runs. Internal: it's never exported.
class const RuleIds() {
  /// Creates the checker.
  this;

  /// Throws an [ArgumentError] when two of [entries] share an id, or one is
  /// [Config.parseErrorId], since config and violation ids couldn't tell
  /// them apart.
  void check(List<RuleEntry> entries) {
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
}
