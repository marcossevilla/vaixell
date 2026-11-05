import 'package:test/test.dart';
import 'package:vaixell/src/config/presets.dart';
import 'package:vaixell/src/rules/registry.dart';
import 'package:vaixell/vaixell.dart';

void main() {
  group(Presets, () {
    test('recommended reports syntax errors and enables every rule', () {
      final recommended = const Presets().all['recommended']!;
      expect(
        recommended,
        equals({
          'parse-error': Severity.error,
          for (final rule in const RuleRegistry().all)
            rule.id: rule.defaultSeverity,
        }),
      );
    });
  });
}
