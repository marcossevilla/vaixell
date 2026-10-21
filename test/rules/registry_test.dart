import 'package:test/test.dart';
import 'package:vaixell/src/engine/violation.dart';
import 'package:vaixell/src/rules/registry.dart';

void main() {
  test('RuleRegistry lists every rule with a unique id', () {
    final ids = const RuleRegistry().all.map((r) => r.id).toList();
    expect(
      ids,
      equals([
        'parse-error',
        'top-level-function',
        'top-level-variable',
        'extension-declaration',
        'static-method',
        'raw-json',
      ]),
    );
  });

  test('every rule defaults to error', () {
    for (final rule in const RuleRegistry().all) {
      expect(rule.defaultSeverity, equals(Severity.error), reason: rule.id);
    }
  });
}
