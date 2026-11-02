import 'package:test/test.dart';
import 'package:vaixell/src/rules/registry.dart';
import 'package:vaixell/src/violation/violation.dart';

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
        'await-receiver',
      ]),
    );
  });

  test('each rule has the expected default severity', () {
    const warnings = {'await-receiver'};
    for (final rule in const RuleRegistry().all) {
      expect(
        rule.defaultSeverity,
        equals(warnings.contains(rule.id) ? Severity.warning : Severity.error),
        reason: rule.id,
      );
    }
  });
}
