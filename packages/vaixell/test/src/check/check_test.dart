import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

import '../../helpers/git_repo.dart';
import '../../helpers/memory_source_tree.dart';

void main() {
  group(Check, () {
    Future<Report> check({
      List<String> paths = const [],
      String? gitDiff,
      String? baseline,
      String? root,
    }) => Check(root: root ?? d.sandbox)(
      paths: paths,
      gitDiff: gitDiff,
      baseline: baseline,
    );

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
      });

      test('explicit paths override discovery', () async {
        final paths = ['packages/b', 'packages/b/', './packages/b'];
        final report = await check(paths: paths);
        expect(
          ids(report.violations),
          equals(['top-level-function:packages/b/lib/b.dart:b']),
        );
      });

      test('. checks only the root package', () async {
        final report = await check(paths: ['.']);
        expect(
          ids(report.violations),
          equals(['top-level-function:lib/root.dart:root']),
        );
      });

      test('compares workspace members with git-diff', () async {
        await gitInit(d.sandbox);
        await gitCommitAll(d.sandbox);
        await d.dir('packages/b/lib', [
          d.file('b.dart', 'final y = 1;\nvoid added() {}\n'),
        ]).create();
        await d.dir('packages/c', [
          d.file('pubspec.yaml', 'name: c\n'),
          d.dir('lib', [d.file('c.dart', 'void c() {}\n')]),
        ]).create();
        await d.file('pubspec.yaml', '''
name: w
workspace:
  - packages/a
  - packages/b
  - packages/c
''').create();

        final report = await check(gitDiff: 'main');
        expect(
          ids(report.failing),
          equals([
            'top-level-function:packages/b/lib/b.dart:added',
            'top-level-function:packages/c/lib/c.dart:c',
          ]),
        );
        expect(
          report.diff!.fixed,
          equals(['top-level-function:packages/b/lib/b.dart:b']),
        );
      });

      test('throws a ConfigException on an invalid workspace', () async {
        await d.file('pubspec.yaml', 'workspace:\n  - packages/c\n').create();
        await expectLater(check(), throwsA(isA<ConfigException>()));
      });

      test('throws a ConfigException with the member config path', () async {
        await d
            .file('packages/b/analysis_options.yaml', 'vaixell:\n  bad: 1\n')
            .create();
        await expectLater(
          check(),
          throwsA(
            isA<ConfigException>().having(
              (e) => '$e',
              'message',
              startsWith(
                'packages/b/analysis_options.yaml:2:3: Unknown key `bad`',
              ),
            ),
          ),
        );
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

    group('git-diff', () {
      setUp(() async {
        await gitInit(d.sandbox);
        await writeLib({'a.dart': 'void old() {}\nvoid kept() {}\n'});
        await gitCommitAll(d.sandbox);
        await git(d.sandbox, ['checkout', '-q', '-b', 'feature']);
      });

      test('reports added and fixed violations', () async {
        await File(d.path('lib/a.dart'))
            .writeAsString('// Moved down.\nvoid kept() {}\nvoid added() {}\n');
        await gitCommitAll(d.sandbox);

        final report = await check(gitDiff: 'main');
        expect(report.mode, equals(ReportMode.diff));
        expect(ids(report.failing), ['top-level-function:lib/a.dart:added']);
        expect(report.diff!.fixed, ['top-level-function:lib/a.dart:old']);
      });

      test('compares against the merge-base, not the tip of the ref', () async {
        await git(d.sandbox, ['checkout', '-q', 'main']);
        await writeLib({'b.dart': 'void onMain() {}\n'});
        await gitCommitAll(d.sandbox);
        await git(d.sandbox, ['checkout', '-q', 'feature']);

        final report = await check(gitDiff: 'main');
        expect(report.failing, isEmpty);
        expect(report.diff!.fixed, isEmpty);
      });

      test('counts uncommitted and untracked changes as head', () async {
        await writeLib({'b.dart': 'void untracked() {}\n'});
        final report = await check(gitDiff: 'main');
        expect(
          ids(report.failing),
          equals(['top-level-function:lib/b.dart:untracked']),
        );
      });

      test('uses the head config for both sides', () async {
        await d
            .file(
              'analysis_options.yaml',
              'vaixell:\n  rules:\n    top-level-function: off\n',
            )
            .create();
        final report = await check(gitDiff: 'main');
        expect(report.violations, isEmpty);
        expect(report.diff!.fixed, isEmpty);
      });

      test('works for a package in a subdirectory', () async {
        await d.dir('pkg', [
          d.dir('lib', [d.file('a.dart', 'void old() {}\n')]),
        ]).create();
        await gitCommitAll(d.sandbox);
        await d.dir('pkg/lib', [
          d.file('a.dart', 'void added() {}\n'),
        ]).create();

        final report = await check(gitDiff: 'HEAD', root: d.path('pkg'));
        expect(ids(report.failing), ['top-level-function:lib/a.dart:added']);
        expect(report.diff!.fixed, ['top-level-function:lib/a.dart:old']);
      });

      test('suppresses the baseline ids', () async {
        await writeLib({
          'a.dart': 'void kept() {}\n',
          'b.dart': 'void known() {}\nvoid added() {}\n',
        });
        await d
            .file(
              'baseline.json',
              '{"schemaVersion": 1, "violations": '
                  '["top-level-function:lib/b.dart:known"]}',
            )
            .create();

        final report = await check(gitDiff: 'main', baseline: 'baseline.json');
        expect(report.mode, equals(ReportMode.diff));
        expect(ids(report.failing), ['top-level-function:lib/b.dart:added']);
        expect(report.diff!.fixed, ['top-level-function:lib/a.dart:old']);
      });

      test('throws a GitException for a ref that can not be found', () async {
        await expectLater(
          check(gitDiff: 'origin/main'),
          throwsA(
            isA<GitException>().having(
              (e) => e.message,
              'message',
              startsWith('Could not find the git ref `origin/main`.'),
            ),
          ),
        );
      });

      test('throws a GitException outside a git repository', () async {
        // The sandbox is a repository, so use a directory outside it.
        final plain = await Directory.systemTemp.createTemp('vaixell_');
        addTearDown(() => plain.delete(recursive: true));
        await expectLater(
          check(gitDiff: 'main', root: plain.path),
          throwsA(isA<GitException>()),
        );
      });
    });

    group('collaborators', () {
      final packages = [Package(path: '', config: Config.recommended())];
      const violation = Violation(
        id: 'top-level-function:lib/a.dart:foo',
        rule: 'top-level-function',
        severity: Severity.error,
        path: 'lib/a.dart',
        line: 1,
        column: 6,
        message: 'message',
      );

      late MemorySourceTree tree;
      late _MockPackageResolver packageResolver;
      late _MockEngine engine;
      late _MockBaselineFile baselineFile;
      late _MockGitRunner git;
      late _MockClosableSourceTree base;
      late List<String> openedCommits;

      setUpAll(() {
        registerFallbackValue(MemorySourceTree({}));
        registerFallbackValue(<Package>[]);
      });

      setUp(() {
        tree = MemorySourceTree({});
        packageResolver = _MockPackageResolver();
        engine = _MockEngine();
        baselineFile = _MockBaselineFile();
        git = _MockGitRunner();
        base = _MockClosableSourceTree();
        openedCommits = [];
        when(() => packageResolver(any())).thenAnswer((_) async => packages);
        when(
          () => engine.run(
            tree: any(named: 'tree'),
            packages: any(named: 'packages'),
          ),
        ).thenAnswer((_) async => [violation]);
        when(() => git.mergeBase(any())).thenAnswer((_) async => 'abc');
        when(base.close).thenAnswer((_) async {});
      });

      Check build() => Check(
        root: '/repo',
        tree: tree,
        git: git,
        openGitSourceTree: (commit) {
          openedCommits.add(commit);
          return base;
        },
        packageResolver: packageResolver,
        engine: engine,
        baselineFile: baselineFile,
      );

      test('resolves the packages with the given resolver', () async {
        await build()(paths: ['x']);
        verify(() => packageResolver(['x'])).called(1);
        verify(() => engine.run(tree: tree, packages: packages)).called(1);
      });

      test('reads the baseline with the given baseline file', () async {
        when(() => baselineFile.read(any()))
            .thenAnswer((_) async => Baseline([violation.id]));
        final report = await build()(baseline: 'baseline.json');
        expect(report.failing, isEmpty);
        verify(() => baselineFile.read('/repo/baseline.json')).called(1);
      });

      test('runs the base side on the opened git tree', () async {
        when(() => engine.run(tree: base, packages: packages))
            .thenAnswer((_) async => []);
        final report = await build()(gitDiff: 'main');
        expect(ids(report.failing), [violation.id]);
        verify(() => git.mergeBase('main')).called(1);
        expect(openedCommits, ['abc']);
        verify(base.close).called(1);
      });

      test('closes the base tree when the base run fails', () async {
        when(() => engine.run(tree: base, packages: packages))
            .thenThrow(StateError('boom'));
        await expectLater(build()(gitDiff: 'main'), throwsA(isA<StateError>()));
        verify(base.close).called(1);
      });
    });
  });
}

class _MockPackageResolver extends Mock implements PackageResolver;

class _MockEngine extends Mock implements Engine;

class _MockBaselineFile extends Mock implements BaselineFile;

class _MockGitRunner extends Mock implements GitRunner;

class _MockClosableSourceTree extends Mock implements ClosableSourceTree;
