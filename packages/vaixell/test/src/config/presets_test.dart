import 'package:test/test.dart';
import 'package:vaixell/src/config/presets.dart';
import 'package:vaixell/src/rules/registry.dart';
import 'package:vaixell/vaixell.dart';

void main() {
  group(Presets, () {
    test('recommended enables generated-json as a warning and every other '
        'rule as an error', () {
      final recommended = const Presets().all['recommended']!;
      expect(
        recommended.keys,
        equals([for (final rule in const RuleRegistry().all) rule.id]),
      );
      expect(
        recommended,
        equals({
          for (final rule in const RuleRegistry().all)
            rule.id: rule.id == 'generated-json'
                ? Severity.warning
                : Severity.error,
        }),
      );
    });
  });
}
