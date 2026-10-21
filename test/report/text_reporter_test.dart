import 'package:test/test.dart';
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
      TextReporter(out).write(const Report.full([]));
      expect(out.toString(), equals('No violations found.\n'));
    });

    test('prints one line per violation and a summary', () {
      TextReporter(out).write(
        Report.full([
          _violation('top-level-function:lib/a.dart:foo'),
          _violation(
            'top-level-function:lib/a.dart:bar',
            severity: Severity.warning,
          ),
        ]),
      );
      expect(
        out.toString(),
        equals(
          'lib/a.dart:3:6: error: Message. [top-level-function:lib/a.dart:foo]\n'
          'lib/a.dart:3:6: warning: Message. '
          '[top-level-function:lib/a.dart:bar]\n'
          '2 violations found.\n',
        ),
      );
    });

    test('uses the singular for one violation', () {
      TextReporter(out).write(Report.full([_violation('x')]));
      expect(out.toString(), endsWith('\n1 violation found.\n'));
    });

    test('reports only new and fixed violations in a diff', () {
      final added = _violation('top-level-function:lib/a.dart:foo');
      TextReporter(out).write(
        Report.compared(
          ReportMode.diff,
          [added, _violation('top-level-function:lib/a.dart:old')],
          DiffResult(
            added: [added],
            fixed: const ['top-level-function:lib/a.dart:bar'],
          ),
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
      TextReporter(out).write(
        const Report.compared(
          ReportMode.baseline,
          [],
          DiffResult(added: [], fixed: []),
        ),
      );
      expect(out.toString(), equals('0 new violations, 0 fixed.\n'));
    });
  });
}
