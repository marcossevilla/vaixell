import 'package:test/test.dart';
import 'package:vaixell/vaixell.dart';

void main() {
  group(Violation, () {
    const violation = Violation(
      id: 'top-level-function:lib/a.dart:foo',
      rule: 'top-level-function',
      severity: Severity.warning,
      path: 'lib/a.dart',
      line: 3,
      column: 6,
      message: 'Message.',
    );

    test('toJson has the documented keys and values', () {
      expect(
        violation.toJson(),
        equals({
          'id': 'top-level-function:lib/a.dart:foo',
          'rule': 'top-level-function',
          'severity': 'warning',
          'path': 'lib/a.dart',
          'line': 3,
          'column': 6,
          'message': 'Message.',
        }),
      );
    });

    test('toJson includes docs when the rule has them', () {
      final documented = Violation(
        id: 'top-level-function:lib/a.dart:foo',
        rule: 'top-level-function',
        severity: Severity.error,
        path: 'lib/a.dart',
        line: 3,
        column: 6,
        message: 'Message.',
        docs: Uri.parse('https://example.com/top-level-function.md'),
      );
      expect(
        documented.toJson(),
        containsPair('docs', 'https://example.com/top-level-function.md'),
      );
    });

    test('toString shows the id and the location', () {
      expect(
        violation.toString(),
        equals(
          'Violation(top-level-function:lib/a.dart:foo at lib/a.dart:3:6)',
        ),
      );
    });
  });
}
