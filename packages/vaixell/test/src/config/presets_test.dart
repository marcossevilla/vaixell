import 'package:test/test.dart';
import 'package:vaixell/src/config/presets.dart';
import 'package:vaixell/src/rules/registry.dart';

void main() {
  group(Presets, () {
    test('recommended enables every rule at its default severity', () {
      final recommended = const Presets().all['recommended']!;
      expect(
        recommended,
        equals({
          for (final rule in const RuleRegistry().all)
            rule.id: rule.defaultSeverity,
        }),
      );
    });
  });
}
