import 'package:test/test.dart';
import 'package:vaixell/vaixell.dart';

Violation _violation(String id, {Severity severity = Severity.error}) =>
    Violation(
      id: id,
      rule: 'r',
      severity: severity,
      path: 'lib/a.dart',
      line: 1,
      column: 1,
      message: 'm',
    );

final Violation _error = _violation('e');
final Violation _warning = _violation('w', severity: Severity.warning);
final Violation _info = _violation('i', severity: Severity.info);

void main() {
  group(Report, () {
    group('reported', () {
      test('is every violation in a full run', () {
        expect(Report.full([_warning]).reported, equals([_warning]));
      });

      for (final mode in [ReportMode.diff, ReportMode.baseline]) {
        test('is the added violations in a ${mode.name} run', () {
          expect(
            Report.compared(mode, [
              _warning,
              _error,
            ], DiffResult(added: [_error], fixed: const ['z'])).reported,
            equals([_error]),
          );
        });
      }

      test('is empty when a compared run adds nothing', () {
        expect(
          Report.compared(ReportMode.baseline, [
            _warning,
          ], const DiffResult(added: [], fixed: [])).reported,
          isEmpty,
        );
      });
    });

    group('fails', () {
      test('when a reported violation is an error', () {
        expect(Report.full([_info, _error]).fails(), isTrue);
      });

      test('not when every reported violation is a warning or info', () {
        expect(Report.full([_warning, _info]).fails(), isFalse);
      });

      test('when a reported violation is a warning and they are fatal', () {
        expect(Report.full([_warning]).fails(fatalWarnings: true), isTrue);
      });

      test('never on info, even when warnings are fatal', () {
        expect(Report.full([_info]).fails(fatalWarnings: true), isFalse);
      });

      test('not on an error that is not reported', () {
        expect(
          Report.compared(ReportMode.diff, [
            _error,
            _info,
          ], DiffResult(added: [_info], fixed: const [])).fails(),
          isFalse,
        );
      });
    });

    group('toJson summary', () {
      test('counts each severity in a full run', () {
        final report = Report.full([
          _error,
          _warning,
          _violation('w2', severity: Severity.warning),
          _info,
        ]);
        expect(
          report.toJson()['summary'],
          equals({'total': 4, 'error': 1, 'warning': 2, 'info': 1}),
        );
      });

      test('counts every violation, and the new and fixed ones, in a '
          'compared run', () {
        final report = Report.compared(ReportMode.diff, [
          _error,
          _warning,
          _info,
        ], DiffResult(added: [_info], fixed: const ['x', 'y']));
        expect(
          report.toJson()['summary'],
          equals({
            'total': 3,
            'error': 1,
            'warning': 1,
            'info': 1,
            'new': 1,
            'fixed': 2,
          }),
        );
      });
    });
  });
}
