import 'package:theseus_cli/src/engine/violation.dart';
import 'package:theseus_cli/src/rules/registry.dart';

/// The built-in presets that a config can `include`.
class Presets {
  /// Creates the preset catalog.
  const new();

  /// The preset used when a config doesn't `include` one.
  static const String defaultPreset = 'recommended';

  /// The severities of each preset, by preset name and then rule id.
  ///
  /// `recommended` enables every rule at its default severity.
  Map<String, Map<String, Severity>> get all => {
    defaultPreset: {
      for (final rule in const RuleRegistry().all)
        rule.id: rule.defaultSeverity,
    },
  };
}
