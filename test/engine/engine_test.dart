import 'package:test/test.dart';
import 'package:theseus_cli/theseus_cli.dart';

import '../helpers/memory_source_tree.dart';

Future<List<Violation>> _run(Map<String, String> files) =>
    Engine(tree: MemorySourceTree(files)).run();

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

    test('uses the given rules only', () async {
      final engine = Engine(
        tree: MemorySourceTree({'lib/a.dart': 'void foo() {}\n'}),
        rules: const [],
      );
      expect(await engine.run(), isEmpty);
    });
  });
}
