import 'dart:convert';
import 'dart:io';

import 'package:io/io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

import '../../helpers/check.dart';
import '../../helpers/git_repo.dart';

/// Compares [actual] with `test/src/report/goldens/<name>.json`.
///
/// Run with `UPDATE_GOLDENS=1` to rewrite the golden files.
void _expectGolden(String actual, String name) {
  final golden = File('test/src/report/goldens/$name.json');
  if (Platform.environment['UPDATE_GOLDENS'] == '1') {
    golden.writeAsStringSync(actual);
  }
  expect(actual, equals(golden.readAsStringSync()));
}

void main() {
  group(JsonReporter, () {
    test('writes one indented document and a trailing newline', () {
      final out = StringBuffer();
      JsonReporter(out).write(const Report.full([]));
      expect(
        out.toString(),
        equals(
          '{\n'
          '  "schemaVersion": 1,\n'
          '  "mode": "full",\n'
          '  "violations": [],\n'
          '  "summary": {\n'
          '    "violations": 0,\n'
          '    "errors": 0,\n'
          '    "warnings": 0\n'
          '  }\n'
          '}\n',
        ),
      );
    });

    test('Report.failing is every violation in a full run', () {
      const violation = Violation(
        id: 'x',
        rule: 'r',
        severity: Severity.warning,
        path: 'lib/a.dart',
        line: 1,
        column: 1,
        message: 'm',
      );
      expect(const Report.full([violation]).failing, equals([violation]));
      expect(
        const Report.compared(ReportMode.baseline, [
          violation,
        ], DiffResult(added: [], fixed: [])).failing,
        isEmpty,
      );
    });
  });

  group('--format=json', () {
    late StringBuffer out;
    late StringBuffer err;

    Future<int?> run(List<String> arguments) {
      out = StringBuffer();
      err = StringBuffer();
      return runCheck(
        ['--format=json', ...arguments],
        root: d.sandbox,
        out: out,
        err: err,
      );
    }

    setUp(() async {
      await d
          .file(
            'analysis_options.yaml',
            'vaixell:\n  rules:\n    top-level-variable: warning\n',
          )
          .create();
      await d.dir('lib', [
        d.file('a.dart', 'void foo() {}\nfinal limit = 1;\n'),
        d.file('b.dart', 'class B {\n'),
      ]).create();
    });

    test('full mode', () async {
      expect(await run([]), equals(1));
      expect(err.toString(), isEmpty);
      expect(() => jsonDecode(out.toString()), returnsNormally);
      _expectGolden(out.toString(), 'full');
    });

    test('diff mode', () async {
      await gitInit(d.sandbox);
      await gitCommitAll(d.sandbox);
      await d.dir('lib', [
        d.file('a.dart', 'final limit = 1;\nvoid bar() {}\n'),
      ]).create();

      expect(await run(['--git-diff=main']), equals(1));
      expect(err.toString(), isEmpty);
      _expectGolden(out.toString(), 'diff');
    });

    test('baseline mode', () async {
      await d
          .file(
            'baseline.json',
            '{"schemaVersion": 1, "violations": '
                '["parse-error:lib/b.dart", "top-level-function:lib/a.dart:gone"]}',
          )
          .create();

      expect(await run(['--baseline=baseline.json']), equals(1));
      expect(err.toString(), isEmpty);
      _expectGolden(out.toString(), 'baseline');
    });

    test('--write-baseline keeps stdout empty', () async {
      expect(
        await run(['--write-baseline=baseline.json']),
        equals(ExitCode.success.code),
      );
      expect(out.toString(), isEmpty);
      expect(
        err.toString(),
        equals('Wrote 3 violation ids to baseline.json.\n'),
      );
    });

    test('errors still go to stderr only', () async {
      await d.file('analysis_options.yaml', 'vaixell:\n  nope: 1\n').create();
      expect(await run([]), equals(ExitCode.config.code));
      expect(out.toString(), isEmpty);
    });
  });
}
