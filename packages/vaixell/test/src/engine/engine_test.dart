import 'package:glob/glob.dart';
import 'package:test/test.dart';
import 'package:vaixell/src/rules/top_level_function.dart';
import 'package:vaixell/vaixell.dart';

import '../../helpers/memory_source_tree.dart';

Future<List<Violation>> _run(Map<String, String> files, {Config? config}) =>
    const Engine().run(
      tree: MemorySourceTree(files),
      packages: [
        Package(
          path: '',
          config: config ?? Config.recommended(Recommended.rules),
        ),
      ],
    );

/// Reports every file at its start, unless [skips] is set.
final class const _FileRule({final bool skips = false}) extends Rule {
  @override
  String get id => 'file';

  @override
  bool shouldCheck(DartFile file) => !skips;

  @override
  List<Finding> check(DartFile file) => [
    Finding(offset: 0, message: 'File ${file.packagePath}.'),
  ];
}

/// Reports 20 findings at the start of every file.
final class const _RepeatRule(@override final String id) extends Rule {
  @override
  List<Finding> check(DartFile file) => [
    for (var i = 0; i < 20; i++) Finding(offset: 0, message: '$id $i'),
  ];
}

/// Reports the resolved path of every import.
final class const _ImportRule() extends Rule with ChecksImports {
  @override
  String get id => 'import';

  @override
  Finding? checkImport(DartFile file, Import import) =>
      Finding.at(import, message: '${import.path}');
}

void main() {
  group(Engine, () {
    test('reports a top-level function and a broken file', () async {
      final violations = await _run({
        'lib/a.dart': 'void foo() {}\n',
        'lib/b.dart': 'class B {\n',
      });
      expect(violations.map((v) => v.id), [
        'top-level-function:lib/a.dart:foo',
        'parse-error:lib/b.dart',
      ]);
      final foo = violations.first;
      expect(foo.rule, equals('top-level-function'));
      expect(foo.severity, equals(Severity.error));
      expect(foo.path, equals('lib/a.dart'));
      expect((foo.line, foo.column), equals((1, 6)));
      expect(foo.toString(), equals('Violation(${foo.id} at lib/a.dart:1:6)'));
    });

    test('ids stay the same when code moves', () async {
      final before = await _run({'lib/a.dart': 'void foo() {}\n'});
      final after = await _run({
        'lib/a.dart':
            'class A {}\n\n\n// comment\n\nvoid bar() {}\nvoid foo() {}\n',
      });
      expect(before.single.id, equals('top-level-function:lib/a.dart:foo'));
      expect(after.map((v) => v.id), contains(before.single.id));
      expect(after.last.line, equals(7));
    });

    test('numbers duplicate ids in source order', () async {
      final violations = await _run({
        'lib/a.dart': 'void foo() {}\nvoid foo() {}\n',
      });
      expect(violations.map((v) => v.id), [
        'top-level-function:lib/a.dart:foo',
        'top-level-function:lib/a.dart:foo#2',
      ]);
    });

    test('builds container ids for the v1 rules', () async {
      final violations = await _run({
        'lib/a.dart': '''
const limit = 1;
extension on int { static void a() {} }
extension on String {}
class Foo { static void bar() {} }
''',
      });
      expect(violations.map((v) => v.id), [
        'top-level-variable:lib/a.dart:limit',
        'extension-declaration:lib/a.dart:<unnamed>',
        'static-method:lib/a.dart:<unnamed>.a',
        'extension-declaration:lib/a.dart:<unnamed>#2',
        'static-method:lib/a.dart:Foo.bar',
      ]);
    });

    test('reports await-receiver as a warning', () async {
      final violations = await _run({
        'lib/a.dart': '''
class Foo {
  Future<void> bar() async {
    (await f).x;
    (await g).y;
  }
}
''',
      });
      expect(violations.map((v) => v.id), [
        'await-receiver:lib/a.dart:Foo.bar@f',
        'await-receiver:lib/a.dart:Foo.bar@g',
      ]);
      expect(violations.map((v) => v.severity), everyElement(Severity.warning));
      expect((violations.first.line, violations.first.column), equals((3, 6)));
    });

    test('scans only non-generated Dart files under lib/', () async {
      final violations = await _run({
        'bin/main.dart': 'void foo() {}\n',
        'test/a_test.dart': 'void foo() {}\n',
        'lib/a.g.dart': 'void foo() {}\n',
        'lib/a.freezed.dart': 'void foo() {}\n',
        'lib/README.md': 'void foo() {}\n',
        'lib/src/c.dart': 'void foo() {}\n',
      });
      expect(violations.map((v) => v.path), ['lib/src/c.dart']);
    });

    test('allows a top-level main in lib/', () async {
      expect(await _run({'lib/main.dart': 'void main() {}\n'}), isEmpty);
    });

    test('runs only parse-error on files with syntax errors', () async {
      final violations = await _run({'lib/a.dart': 'void foo() {}\nclass {\n'});
      expect(violations.map((v) => v.rule), ['parse-error']);
    });

    group('parse-error', () {
      test('reports one violation at the first error', () async {
        final violations = await _run({'lib/a.dart': 'class A {\n'});
        final violation = violations.single;
        expect(violation.id, 'parse-error:lib/a.dart');
        expect(violation.severity, Severity.error);
        expect(violation.message, startsWith('Syntax error: '));
        expect(violation.message, isNot(contains('more)')));
      });

      test('mentions how many more errors there are', () async {
        final violations = await _run({
          'lib/a.dart': 'class A { void f( }\nclass {\n',
        });
        expect(violations.single.message, matches(r'\(and \d+ more\)$'));
      });

      test('uses the severity from the config', () async {
        final violations = await _run(
          {'lib/a.dart': 'class {\n'},
          config: const Config(rules: [], parseErrorSeverity: Severity.warning),
        );
        expect(violations.single.severity, Severity.warning);
      });

      test('is an error by default', () async {
        final violations = await _run({
          'lib/a.dart': 'class {\n',
        }, config: const Config(rules: []));
        expect(violations.single.severity, Severity.error);
      });
    });

    test('sorts by path, line and column', () async {
      final violations = await _run({
        'lib/b.dart': 'void b() {}\n',
        'lib/a.dart': 'void a2() {}\nvoid a1() {} void a3() {}\n',
      });
      expect(violations.map((v) => v.id.split(':').last), [
        'a2',
        'a1',
        'a3',
        'b',
      ]);
    });

    test('keeps the rule order for findings at the same position', () async {
      final violations = await _run(
        {'lib/a.dart': 'void a() {}\n'},
        config: const Config(
          rules: [
            (_RepeatRule('first'), Severity.error),
            (_RepeatRule('second'), Severity.error),
          ],
        ),
      );
      expect(violations.map((v) => v.message), [
        for (final rule in ['first', 'second'])
          for (var i = 0; i < 20; i++) '$rule $i',
      ]);
    });

    test('runs only the rules enabled in the config', () async {
      final violations = await _run({
        'lib/a.dart': 'void foo() {}\n',
        'lib/b.dart': 'class {\n',
      }, config: const Config(rules: []));
      expect(violations.map((v) => v.rule), ['parse-error']);
    });

    test('uses the severities from the config', () async {
      final violations = await _run(
        {'lib/a.dart': 'void foo() {}\n'},
        config: const Config(
          rules: [(TopLevelFunctionRule(), Severity.warning)],
        ),
      );
      expect(violations.single.severity, equals(Severity.warning));
    });

    test('skips files excluded by the config', () async {
      final violations = await _run(
        {
          'lib/a.dart': 'void foo() {}\n',
          'lib/legacy/b.dart': 'void foo() {}\n',
        },
        config: Config(
          rules: Config.recommended(Recommended.rules).rules,
          exclude: [Glob('lib/legacy/**')],
        ),
      );
      expect(violations.map((v) => v.path), ['lib/a.dart']);
    });

    test('checks each package with its own config', () async {
      final violations = await const Engine().run(
        tree: MemorySourceTree({
          'lib/root.dart': 'void root() {}\n',
          'packages/a/lib/a.dart': 'void a() {}\nfinal x = 1;\n',
          'packages/a/lib/legacy/old.dart': 'void old() {}\n',
          'packages/b/lib/b.dart': 'void b() {}\n',
          'packages/b/test/b_test.dart': 'void t() {}\n',
        }),
        packages: [
          Package(path: '', config: Config.recommended(Recommended.rules)),
          Package(
            path: 'packages/a',
            config: Config(
              rules: const [(TopLevelFunctionRule(), Severity.warning)],
              exclude: [Glob('lib/legacy/**')],
              root: 'packages/a',
            ),
          ),
          Package(
            path: 'packages/b',
            config: Config.recommended(Recommended.rules),
          ),
        ],
      );
      expect(
        violations.map((v) => '${v.id} ${v.severity.name}'),
        equals([
          'top-level-function:lib/root.dart:root error',
          'top-level-function:packages/a/lib/a.dart:a warning',
          'top-level-function:packages/b/lib/b.dart:b error',
        ]),
      );
    });

    test('runs injected rules with their configured severity', () async {
      final violations = await const Engine().run(
        tree: MemorySourceTree({'packages/a/lib/a.dart': 'class A {}\n'}),
        packages: [
          const Package(
            path: 'packages/a',
            config: Config(rules: [(_FileRule(), Severity.warning)]),
          ),
        ],
      );
      expect(violations.single.id, 'file:packages/a/lib/a.dart');
      expect(violations.single.severity, Severity.warning);
      expect(violations.single.message, 'File lib/a.dart.');
    });

    test('does not check files a rule skips', () async {
      final violations = await _run(
        {'lib/a.dart': 'class A {}\n'},
        config: const Config(rules: [(_FileRule(skips: true), Severity.error)]),
      );
      expect(violations, isEmpty);
    });

    test("resolves imports of the package's own name", () async {
      final violations = await const Engine().run(
        tree: MemorySourceTree({
          'packages/app/lib/a.dart':
              "import 'package:app/src/b.dart';\n"
              "import 'package:other/c.dart';\n",
        }),
        packages: [
          const Package(
            path: 'packages/app',
            name: 'app',
            config: Config(rules: [(_ImportRule(), Severity.error)]),
          ),
        ],
      );
      expect(violations.map((v) => v.message), [
        'packages/app/lib/src/b.dart',
        'null',
      ]);
    });
  });
}
