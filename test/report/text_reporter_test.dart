import 'package:test/test.dart';
import 'package:theseus_cli/src/report/text_reporter.dart';
import 'package:theseus_cli/theseus_cli.dart';

Violation _violation(String id, {Severity severity = Severity.error}) =>
    Violation(
      id: id,
      rule: 'top-level-function',
      severity: severity,
      path: 'lib/a.dart',
      line: 3,
      column: 6,
      message: 'Message.',
    );

void main() {
  group(TextReporter, () {
    late StringBuffer out;

    setUp(() => out = StringBuffer());

    test('prints a summary when there are no violations', () {
      TextReporter(out).report([]);
      expect(out.toString(), equals('No violations found.\n'));
    });

    test('prints one line per violation and a summary', () {
      TextReporter(out).report([
        _violation('top-level-function:lib/a.dart:foo'),
        _violation(
          'top-level-function:lib/a.dart:bar',
          severity: Severity.warning,
        ),
      ]);
      expect(
        out.toString(),
        equals(
          'lib/a.dart:3:6: error: Message. [top-level-function:lib/a.dart:foo]\n'
          'lib/a.dart:3:6: warning: Message. [top-level-function:lib/a.dart:bar]\n'
          '2 violations found.\n',
        ),
      );
    });

    test('uses the singular for one violation', () {
      TextReporter(out).report([_violation('x')]);
      expect(out.toString(), endsWith('\n1 violation found.\n'));
    });

    test('reports new and fixed violations in a diff', () {
      TextReporter(out).reportDiff(
        DiffResult(
          added: [_violation('top-level-function:lib/a.dart:foo')],
          fixed: const ['top-level-function:lib/a.dart:bar'],
        ),
      );
      expect(
        out.toString(),
        equals(
          'lib/a.dart:3:6: error: Message. [top-level-function:lib/a.dart:foo]\n'
          'Fixed: top-level-function:lib/a.dart:bar\n'
          '1 new violation, 1 fixed.\n',
        ),
      );
    });

    test('uses the plural in diff summaries', () {
      TextReporter(out).reportDiff(const DiffResult(added: [], fixed: []));
      expect(out.toString(), equals('0 new violations, 0 fixed.\n'));
    });
  });
}
