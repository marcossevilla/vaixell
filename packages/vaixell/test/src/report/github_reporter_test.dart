import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

Violation _v(
  String id, {
  Severity severity = Severity.error,
  String path = 'lib/a.dart',
  String message = 'Message.',
  int line = 3,
}) => Violation(
  id: id,
  rule: 'top-level-function',
  severity: severity,
  path: path,
  line: line,
  column: 6,
  message: message,
);

void main() {
  group(GithubReporter, () {
    late StringBuffer out;

    setUp(() => out = StringBuffer());

    List<String> lines() => out.toString().trimRight().split('\n');

    test('annotates every violation in a full run', () {
      const GithubReporter().write(
        Report.full([
          _v('top-level-function:lib/a.dart:foo'),
          _v('top-level-variable:lib/a.dart:x', severity: Severity.warning),
        ]),
        out,
      );
      const properties =
          'file=lib/a.dart,line=3,col=6,'
          'title=vaixell top-level-function';
      expect(
        lines(),
        equals([
          '::error $properties::Message. [top-level-function:lib/a.dart:foo]',
          '::warning $properties::Message. [top-level-variable:lib/a.dart:x]',
          '2 violations found.',
        ]),
      );
    });

    test('annotates only new violations in a diff', () {
      final added = _v('top-level-function:lib/a.dart:added');
      const GithubReporter().write(
        Report.compared(ReportMode.diff, [
          added,
          _v('top-level-function:lib/a.dart:old'),
        ], DiffResult(added: [added], fixed: const ['gone'])),
        out,
      );
      expect(lines(), hasLength(2));
      expect(lines().first, endsWith('[top-level-function:lib/a.dart:added]'));
      expect(lines().last, equals('1 new violation, 1 fixed.'));
    });

    test('escapes messages and property values', () {
      const GithubReporter().write(
        Report.full([
          _v(
            'id',
            path: 'lib/a,b:c%.dart',
            message: '100% sure:\r\nyes, really',
          ),
        ]),
        out,
      );
      expect(
        lines().first,
        equals(
          '::error file=lib/a%2Cb%3Ac%25.dart,line=3,col=6,title=vaixell '
          'top-level-function::100%25 sure:%0D%0Ayes, really [id]',
        ),
      );
    });

    test('caps annotations per severity and prints the rest', () {
      const GithubReporter().write(
        Report.full([
          for (var i = 0; i < 12; i++) _v('e$i', line: i + 1),
          for (var i = 0; i < 3; i++)
            _v('w$i', severity: Severity.warning, line: i + 1),
        ]),
        out,
      );
      final output = lines();
      expect(output.where((l) => l.startsWith('::error ')), hasLength(10));
      expect(output.where((l) => l.startsWith('::warning ')), hasLength(3));
      expect(
        output.where((l) => l.startsWith('lib/a.dart:')),
        equals([
          'lib/a.dart:11:6: error: Message. [e10]',
          'lib/a.dart:12:6: error: Message. [e11]',
        ]),
      );
    });

    group('step summary', () {
      late String path;

      setUp(() => path = d.path('summary.md'));

      test('is not written without a path', () {
        const GithubReporter().write(Report.full([_v('x')]), out);
        expect(File(path).existsSync(), isFalse);
      });

      test('is appended to, not overwritten', () {
        File(path).writeAsStringSync('previous step\n');
        GithubReporter(summaryPath: path).write(const Report.full([]), out);
        expect(
          File(path).readAsStringSync(),
          equals(
            'previous step\n'
            '## vaixell\n'
            '\n'
            '**No violations found.** (full mode)\n'
            '\n',
          ),
        );
      });

      test('has tables of new and fixed violations', () {
        final added = _v(
          'top-level-function:lib/a.dart:added',
          message: 'Pipes | and\nnew lines.',
        );
        GithubReporter(summaryPath: path).write(
          Report.compared(ReportMode.baseline, [
            added,
          ], DiffResult(added: [added], fixed: const ['a', 'b'])),
          out,
        );
        expect(
          File(path).readAsStringSync(),
          equals(
            '## vaixell\n'
            '\n'
            '**1 new violation, 2 fixed.** (baseline mode)\n'
            '\n'
            '### New violations\n'
            '\n'
            '| Severity | Rule | File | Message |\n'
            '| --- | --- | --- | --- |\n'
            '| error | `top-level-function` | `lib/a.dart:3:6` | '
            r'Pipes \| and new lines. |'
            '\n'
            '\n'
            '### Fixed\n'
            '\n'
            '- `a`\n'
            '- `b`\n'
            '\n',
          ),
        );
      });

      test('lists every violation and says how many were not annotated', () {
        GithubReporter(summaryPath: path)
            .write(Report.full([for (var i = 0; i < 12; i++) _v('e$i')]), out);
        final summary = File(path).readAsStringSync();
        expect(summary, contains('### Violations\n'));
        expect(
          RegExp(r'^\| error ', multiLine: true).allMatches(summary),
          hasLength(12),
        );
        expect(
          summary,
          endsWith(
            '> 2 violations were not annotated because GitHub shows at most '
            '10 errors and 10 warnings per step. All of them are listed '
            'above.\n\n',
          ),
        );
      });

      test('uses the singular for one violation left out', () {
        GithubReporter(summaryPath: path)
            .write(Report.full([for (var i = 0; i < 11; i++) _v('e$i')]), out);
        expect(
          File(path).readAsStringSync(),
          contains('> 1 violation was not annotated'),
        );
      });
    });
  });
}
