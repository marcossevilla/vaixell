import 'package:test/test.dart';
import 'package:vaixell/vaixell.dart';

void main() {
  group(Report, () {
    group('failing', () {
      const violation = Violation(
        id: 'x',
        rule: 'r',
        severity: Severity.warning,
        path: 'lib/a.dart',
        line: 1,
        column: 1,
        message: 'm',
      );

      test('is every violation in a full run', () {
        expect(const Report.full([violation]).failing, equals([violation]));
      });

      for (final mode in [ReportMode.diff, ReportMode.baseline]) {
        test('is the added violations in a ${mode.name} run', () {
          const added = Violation(
            id: 'y',
            rule: 'r',
            severity: Severity.error,
            path: 'lib/b.dart',
            line: 2,
            column: 1,
            message: 'm',
          );
          expect(
            Report.compared(mode, const [
              violation,
              added,
            ], const DiffResult(added: [added], fixed: ['z'])).failing,
            equals([added]),
          );
        });
      }

      test('is empty when a compared run adds nothing', () {
        expect(
          const Report.compared(ReportMode.baseline, [
            violation,
          ], DiffResult(added: [], fixed: [])).failing,
          isEmpty,
        );
      });
    });

    test('toJson counts each severity in the summary', () {
      Violation violation(String id, Severity severity) => Violation(
        id: id,
        rule: 'r',
        severity: severity,
        path: 'lib/a.dart',
        line: 1,
        column: 1,
        message: 'm',
      );
      final report = Report.full([
        violation('a', Severity.error),
        violation('b', Severity.warning),
        violation('c', Severity.warning),
        violation('d', Severity.info),
      ]);
      expect(
        report.toJson()['summary'],
        equals({'violation': 4, 'error': 1, 'warning': 2, 'info': 1}),
      );
    });
  });
}
