import 'package:test/test.dart';
import 'package:vaixell/src/config/presets.dart';
import 'package:vaixell/src/rules/registry.dart';
import 'package:vaixell/vaixell.dart';

void main() {
  group(Presets, () {
    test('recommended enables every rule as an error', () {
      final recommended = const Presets().all['recommended']!;
      expect(
        recommended.keys,
        equals([for (final rule in const RuleRegistry().all) rule.id]),
      );
      expect(recommended.values, everyElement(Severity.error));
    });
  });
}
