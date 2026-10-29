import 'dart:convert';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

import '../../helpers/check.dart';
import '../../helpers/memory_source_tree.dart';

void main() {
  group(Check, () {
    Future<Report> check({List<String> paths = const [], String? baseline}) =>
        Check(root: d.sandbox)(paths: paths, baseline: baseline);

    /// Returns the JSON document that `vaixell check --format=json` prints
    /// for [arguments].
    Future<Object?> commandJson(List<String> arguments) async {
      final out = StringBuffer();
      await runCheck(
        ['--format=json', ...arguments],
        root: d.sandbox,
        out: out,
        err: StringBuffer(),
      );
      return jsonDecode('$out');
    }

    Object? json(Report report) => jsonDecode(jsonEncode(report));

    List<String> ids(List<Violation> violations) => [
      for (final v in violations) v.id,
    ];

    Future<void> writeLib(Map<String, String> files) => d.dir('lib', [
      for (final MapEntry(:key, :value) in files.entries) d.file(key, value),
    ]).create();

    group('full', () {
      test('reports every violation', () async {
        await writeLib({'a.dart': 'void foo() {}\n'});
        final report = await check();
        expect(report.mode, equals(ReportMode.full));
        expect(ids(report.violations), ['top-level-function:lib/a.dart:foo']);
        expect(report.diff, isNull);
        expect(json(report), equals(await commandJson([])));
      });

      test('reports nothing for a clean package', () async {
        await writeLib({'main.dart': 'void main() {}\n'});
        expect((await check()).violations, isEmpty);
      });

      test('applies the config severities', () async {
        await writeLib({'a.dart': 'void foo() {}\n'});
        await d
            .file(
              'analysis_options.yaml',
              'vaixell:\n  rules:\n    top-level-function: warning\n',
            )
            .create();
        final [violation] = (await check()).violations;
        expect(violation.severity, equals(Severity.warning));
      });

      test('throws a ConfigException on an invalid config', () async {
        await d
            .file('analysis_options.yaml', 'vaixell:\n  rulez: {}\n')
            .create();
        await expectLater(check(), throwsA(isA<ConfigException>()));
      });

      test('reads the files from the given tree', () async {
        final tree = MemorySourceTree({'lib/c.dart': 'void c() {}\n'});
        final report = await Check(root: d.sandbox, tree: tree)();
        expect(ids(report.violations), ['top-level-function:lib/c.dart:c']);
      });
    });

    group('discovery', () {
      setUp(() async {
        await d.file('pubspec.yaml', '''
name: w
workspace:
  - packages/a
  - packages/b
''').create();
        await d
            .file(
              'analysis_options.yaml',
              'vaixell:\n  rules:\n    top-level-variable: off\n',
            )
            .create();
        await writeLib({'root.dart': 'void root() {}\n'});
        await d.dir('packages/a', [
          d.file('pubspec.yaml', 'name: a\n'),
          d.file(
            'analysis_options.yaml',
            'vaixell:\n  rules:\n    top-level-function: off\n',
          ),
          d.dir('lib', [d.file('a.dart', 'void a() {}\nfinal x = 1;\n')]),
        ]).create();
        await d.dir('packages/b', [
          d.file('pubspec.yaml', 'name: b\n'),
          d.file('analysis_options.yaml', 'include: package:lints/core.yaml\n'),
          d.dir('lib', [d.file('b.dart', 'void b() {}\nfinal y = 1;\n')]),
        ]).create();
      });

      test('checks every workspace member with its nearest config', () async {
        final report = await check();
        expect(
          ids(report.violations),
          equals([
            'top-level-function:lib/root.dart:root',
            'top-level-variable:packages/a/lib/a.dart:x',
            'top-level-function:packages/b/lib/b.dart:b',
          ]),
        );
        expect(json(report), equals(await commandJson([])));
      });

      test('explicit paths override discovery', () async {
        final paths = ['packages/b', 'packages/b/', './packages/b'];
        final report = await check(paths: paths);
        expect(
          ids(report.violations),
          equals(['top-level-function:packages/b/lib/b.dart:b']),
        );
        expect(json(report), equals(await commandJson(paths)));
      });

      test('. checks only the root package', () async {
        final report = await check(paths: ['.']);
        expect(
          ids(report.violations),
          equals(['top-level-function:lib/root.dart:root']),
        );
      });

      test('throws a ConfigException on an invalid workspace', () async {
        await d.file('pubspec.yaml', 'workspace:\n  - packages/c\n').create();
        await expectLater(check(), throwsA(isA<ConfigException>()));
      });
    });

    group('baseline', () {
      setUp(() => writeLib({'a.dart': 'void foo() {}\nvoid bar() {}\n'}));

      test('a fresh baseline suppresses everything', () async {
        await WriteBaseline(root: d.sandbox)('baseline.json');
        final report = await check(baseline: 'baseline.json');
        expect(report.mode, equals(ReportMode.baseline));
        expect(report.violations, hasLength(2));
        expect(report.failing, isEmpty);
        expect(report.diff!.fixed, isEmpty);
      });

      test('reports new violations and stale entries', () async {
        await WriteBaseline(root: d.sandbox)('baseline.json');
        await writeLib({'a.dart': 'void foo() {}\nvoid baz() {}\n'});
        final report = await check(baseline: 'baseline.json');
        expect(ids(report.failing), ['top-level-function:lib/a.dart:baz']);
        expect(report.diff!.fixed, ['top-level-function:lib/a.dart:bar']);
        expect(
          json(report),
          equals(await commandJson(['--baseline=baseline.json'])),
        );
      });

      test('throws a BaselineException for a missing baseline', () async {
        await expectLater(
          check(baseline: 'missing.json'),
          throwsA(
            isA<BaselineException>().having(
              (e) => e.message,
              'message',
              endsWith('missing.json` not found.'),
            ),
          ),
        );
      });

      test('throws a BaselineException for a malformed baseline', () async {
        await d.file('baseline.json', '{"violations": []}').create();
        await expectLater(
          check(baseline: 'baseline.json'),
          throwsA(isA<BaselineException>()),
        );
      });
    });
  });
}
