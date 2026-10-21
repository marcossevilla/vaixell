import 'package:test/test.dart';
import 'package:vaixell/src/rules/static_method.dart';

import '../helpers/parse.dart';

void main() {
  group(StaticMethodRule, () {
    const rule = StaticMethodRule();

    List<String?> symbols(String source) =>
        rule.check(parse(source)).map((f) => f.symbol).toList();

    test('has the expected id', () {
      expect(rule.id, equals('static-method'));
    });

    test('flags public and private static methods in classes', () {
      final findings = rule.check(
        parse(
          'class Foo {\n  static void bar() {}\n  static int _baz() => 1;\n}\n',
        ),
      );
      expect(findings.map((f) => f.symbol), equals(['Foo.bar', 'Foo._baz']));
      expect(findings.first.offset, equals(26));
      expect(
        findings.first.message,
        equals(
          'Static method `Foo.bar` is not allowed. '
          'Use an instance member instead.',
        ),
      );
    });

    test('flags static getters and setters', () {
      final findings = rule.check(
        parse(
          'class Foo {\n'
          '  static int get x => 1;\n'
          '  static set x(int v) {}\n'
          '}\n',
        ),
      );
      expect(findings.map((f) => f.symbol), equals(['Foo.x', 'Foo.x=']));
      expect(findings.map((f) => f.message), [
        startsWith('Static getter `Foo.x`'),
        startsWith('Static setter `Foo.x`'),
      ]);
    });

    test('flags static methods in every kind of container', () {
      expect(symbols('mixin M { static void a() {} }\n'), equals(['M.a']));
      expect(symbols('enum E { x; static void a() {} }\n'), equals(['E.a']));
      expect(
        symbols('extension X on int { static void a() {} }\n'),
        equals(['X.a']),
      );
      expect(
        symbols('extension on int { static void a() {} }\n'),
        equals(['<unnamed>.a']),
      );
      expect(
        symbols('extension type Id(int v) { static void a() {} }\n'),
        equals(['Id.a']),
      );
    });

    test('ignores static fields, constructors and instance members', () {
      final file = parse('''
class Foo {
  Foo();
  factory Foo.create() => Foo();
  static const a = 1;
  static final b = 2;
  void c() {}
  int get d => 1;
}
''');
      expect(rule.check(file), isEmpty);
    });

    test('ignores top-level functions and type aliases', () {
      final file = parse('''
void main() {}
mixin M {}
class A = Object with M;
typedef F = void Function();
''');
      expect(rule.check(file), isEmpty);
    });
  });
}
