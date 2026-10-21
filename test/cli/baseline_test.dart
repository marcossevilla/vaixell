import 'dart:io';

import 'package:io/io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

import '../helpers/git_repo.dart';

void main() {
  group('baselines', () {
    late StringBuffer out;
    late StringBuffer err;

    Future<int> run(List<String> arguments) {
      out = StringBuffer();
      err = StringBuffer();
      return VaixellCommand(
        stdout: out,
        stderr: err,
        root: Directory(d.sandbox),
      ).run(arguments);
    }

    Future<void> writeLib(Map<String, String> files) => d.dir('lib', [
      for (final MapEntry(:key, :value) in files.entries) d.file(key, value),
    ]).create();

    setUp(() => writeLib({'a.dart': 'void foo() {}\nvoid bar() {}\n'}));

    test('--write-baseline writes the ids and exits 0', () async {
      expect(
        await run(['--write-baseline=baseline.json']),
        equals(ExitCode.success.code),
      );
      expect(
        out.toString(),
        equals('Wrote 2 violation ids to baseline.json.\n'),
      );
      await d
          .file(
            'baseline.json',
            '{\n'
                '  "schemaVersion": 1,\n'
                '  "violations": [\n'
                '    "top-level-function:lib/a.dart:bar",\n'
                '    "top-level-function:lib/a.dart:foo"\n'
                '  ]\n'
                '}\n',
          )
          .validate();
    });

    test('--write-baseline uses the singular for one id', () async {
      await writeLib({'a.dart': 'void foo() {}\n'});
      await run(['--write-baseline=baseline.json']);
      expect(
        out.toString(),
        equals('Wrote 1 violation id to baseline.json.\n'),
      );
    });

    test('a fresh baseline suppresses everything', () async {
      await run(['--write-baseline=baseline.json']);
      expect(
        await run(['--baseline=baseline.json']),
        equals(ExitCode.success.code),
      );
      expect(out.toString(), equals('0 new violations, 0 fixed.\n'));
    });

    test('new violations fail and stale entries are listed', () async {
      await run(['--write-baseline=baseline.json']);
      await writeLib({'a.dart': 'void foo() {}\nvoid baz() {}\n'});

      expect(await run(['--baseline=baseline.json']), equals(1));
      expect(
        out.toString(),
        equals(
          'lib/a.dart:2:6: error: Top-level function `baz` is not allowed. '
          'Move it into a class. [top-level-function:lib/a.dart:baz]\n'
          'Fixed: top-level-function:lib/a.dart:bar\n'
          '1 new violation, 1 fixed.\n',
        ),
      );
    });

    test('combines with --git-diff', () async {
      await gitInit(d.sandbox);
      await gitCommitAll(d.sandbox);
      await writeLib({
        'a.dart': 'void foo() {}\n',
        'b.dart': 'void known() {}\nvoid added() {}\n',
      });
      await d
          .file(
            'baseline.json',
            '{"schemaVersion": 1, "violations": '
                '["top-level-function:lib/b.dart:known"]}',
          )
          .create();

      expect(
        await run(['--git-diff=main', '--baseline=baseline.json']),
        equals(1),
      );
      expect(
        out.toString(),
        allOf(
          contains('[top-level-function:lib/b.dart:added]'),
          isNot(contains('lib/b.dart:known]')),
          contains('Fixed: top-level-function:lib/a.dart:bar\n'),
          endsWith('1 new violation, 1 fixed.\n'),
        ),
      );
    });

    test('a missing baseline exits 78', () async {
      expect(
        await run(['--baseline=missing.json']),
        equals(ExitCode.config.code),
      );
      expect(err.toString(), contains('Baseline file `'));
      expect(err.toString(), contains('missing.json` not found.'));
      expect(out.toString(), isEmpty);
    });

    test('a malformed baseline exits 78', () async {
      await d.file('baseline.json', '{"violations": []}').create();
      expect(
        await run(['--baseline=baseline.json']),
        equals(ExitCode.config.code),
      );
      expect(err.toString(), contains('is malformed: '));
    });

    for (final other in ['--git-diff=main', '--baseline=b.json']) {
      test('--write-baseline with $other exits 64', () async {
        expect(
          await run(['--write-baseline=b.json', other]),
          equals(ExitCode.usage.code),
        );
        expect(
          err.toString(),
          startsWith('--write-baseline can not be combined'),
        );
      });
    }
  });
}
