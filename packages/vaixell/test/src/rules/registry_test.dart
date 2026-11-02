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

  test('every rule but await-receiver defaults to error', () {
    expect(
      {
        for (final rule in const RuleRegistry().all)
          rule.id: rule.defaultSeverity,
      },
      equals({
        'parse-error': Severity.error,
        'top-level-function': Severity.error,
        'top-level-variable': Severity.error,
        'extension-declaration': Severity.error,
        'static-method': Severity.error,
        'raw-json': Severity.error,
        'await-receiver': Severity.warning,
      }),
    );
  });
}
