import 'package:test/test.dart';
import 'package:vaixell/vaixell.dart';

void main() {
  group('Recommended.rules', () {
    test('lists every rule with a unique id, without parse-error', () {
      expect(Recommended.rules.map((r) => r.id), [
        'top-level-function',
        'top-level-variable',
        'extension-declaration',
        'static-method',
        'raw-json',
        'generated-json',
        'await-receiver',
      ]);
    });

    test('each rule has the expected default severity', () {
      const warnings = {'generated-json', 'await-receiver'};
      for (final rule in Recommended.rules) {
        expect(
          rule.defaultSeverity,
          equals(
            warnings.contains(rule.id) ? Severity.warning : Severity.error,
          ),
          reason: rule.id,
        );
      }
    });

    test('are all recommended', () {
      expect(Recommended.rules.map((r) => r.recommended), everyElement(isTrue));
    });
  });
}
