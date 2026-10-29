import 'package:glob/glob.dart';
import 'package:test/test.dart';
import 'package:vaixell/vaixell.dart';

import '../../helpers/memory_source_tree.dart';

Future<List<Violation>> _run(Map<String, String> files, {Config? config}) =>
    const Engine().run(
      tree: MemorySourceTree(files),
      packages: [Package(path: '', config: config ?? Config.recommended())],
    );

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

    test('runs only the rules enabled in the config', () async {
      final violations = await _run({
        'lib/a.dart': 'void foo() {}\n',
        'lib/b.dart': 'class {\n',
      }, config: const Config(severities: {'parse-error': Severity.error}));
      expect(violations.map((v) => v.rule), ['parse-error']);
    });

    test('uses the severities from the config', () async {
      final violations = await _run(
        {'lib/a.dart': 'void foo() {}\n'},
        config: const Config(
          severities: {'top-level-function': Severity.warning},
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
          severities: Config.recommended().severities,
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
          Package(path: '', config: Config.recommended()),
          Package(
            path: 'packages/a',
            config: Config(
              severities: const {'top-level-function': Severity.warning},
              exclude: [Glob('lib/legacy/**')],
              root: 'packages/a',
            ),
          ),
          Package(path: 'packages/b', config: Config.recommended()),
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
  });
}
