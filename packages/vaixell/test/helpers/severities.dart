import 'package:vaixell/vaixell.dart';

/// The severity of `parse-error` and of each enabled rule in [config], by
/// id, in reporting order.
Map<String, Severity> severitiesOf(Config config) => {
  'parse-error': config.parseErrorSeverity,
  for (final ConfiguredRule(:rule, :severity) in config.rules)
    rule.id: severity,
};
