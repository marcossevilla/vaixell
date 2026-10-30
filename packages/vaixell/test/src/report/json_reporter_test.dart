import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

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
      const JsonReporter().write(const Report.full([]), out);
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

  group('JSON output of a check', () {
    Future<String> run({String? gitDiff, String? baseline}) async {
      final report = await Check(root: d.sandbox)(
        gitDiff: gitDiff,
        baseline: baseline,
      );
      final out = StringBuffer();
      const JsonReporter().write(report, out);
      return '$out';
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
      final output = await run();
      expect(() => jsonDecode(output), returnsNormally);
      _expectGolden(output, 'full');
    });

    test('diff mode', () async {
      await gitInit(d.sandbox);
      await gitCommitAll(d.sandbox);
      await d.dir('lib', [
        d.file('a.dart', 'final limit = 1;\nvoid bar() {}\n'),
      ]).create();

      _expectGolden(await run(gitDiff: 'main'), 'diff');
    });

    test('baseline mode', () async {
      await d
          .file(
            'baseline.json',
            '{"schemaVersion": 1, "violations": '
                '["parse-error:lib/b.dart", "top-level-function:lib/a.dart:gone"]}',
          )
          .create();

      _expectGolden(await run(baseline: 'baseline.json'), 'baseline');
    });
  });
}
