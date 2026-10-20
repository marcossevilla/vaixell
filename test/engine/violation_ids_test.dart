import 'package:test/test.dart';
import 'package:theseus_cli/src/engine/violation_ids.dart';

void main() {
  group(ViolationIds, () {
    test('uses rule, path and symbol', () {
      expect(
        ViolationIds().next(
          rule: 'static-method',
          path: 'lib/a.dart',
          symbol: 'Foo.bar',
        ),
        equals('static-method:lib/a.dart:Foo.bar'),
      );
    });

    test('leaves out the symbol when there is none', () {
      expect(
        ViolationIds().next(rule: 'parse-error', path: 'lib/b.dart'),
        equals('parse-error:lib/b.dart'),
      );
    });

    test('numbers repeated ids from the second occurrence', () {
      final ids = ViolationIds();
      String next() => ids.next(rule: 'r', path: 'lib/a.dart', symbol: 'x');
      expect([
        next(),
        next(),
        next(),
      ], equals(['r:lib/a.dart:x', 'r:lib/a.dart:x#2', 'r:lib/a.dart:x#3']));
    });

    test('counts each id separately', () {
      final ids = ViolationIds();
      expect(
        ids.next(rule: 'r', path: 'lib/a.dart', symbol: 'x'),
        equals('r:lib/a.dart:x'),
      );
      expect(
        ids.next(rule: 'r', path: 'lib/a.dart', symbol: 'y'),
        equals('r:lib/a.dart:y'),
      );
    });
  });
}
