import 'package:test/test.dart';
import 'package:vaixell/src/rules/top_level_function.dart';
import 'package:vaixell/testing.dart';

const _tester = RuleTester();

void main() {
  group(TopLevelFunctionRule, () {
    const rule = TopLevelFunctionRule();

    test('has the expected id', () {
      expect(rule.id, equals('top-level-function'));
    });

    test('flags top-level functions', () {
      final findings = _tester.checkSource(
        rule,
        'void foo() {}\nint bar() => 1;\n',
      );
      expect(findings.map((f) => f.symbol), equals(['foo', 'bar']));
      expect(
        findings.first.message,
        equals(
          'Top-level function `foo` is not allowed. Move it into a class.',
        ),
      );
      expect(findings.first.offset, equals(5));
    });

    test('flags top-level getters and setters', () {
      final findings = _tester.checkSource(
        rule,
        'int get foo => 1;\nset foo(int v) {}\n',
      );
      expect(findings.map((f) => f.symbol), equals(['foo', 'foo=']));
      expect(findings.map((f) => f.message), [
        contains('Top-level getter `foo`'),
        contains('Top-level setter `foo`'),
      ]);
    });

    test('allows a top-level main function', () {
      expect(_tester.checkSource(rule, 'void main() {}\n'), isEmpty);
      expect(
        _tester.checkSource(rule, 'void main(List<String> args) {}\n'),
        isEmpty,
      );
    });

    test('flags getters and setters named main', () {
      final findings = _tester.checkSource(
        rule,
        'int get main => 1;\nset main(int v) {}\n',
      );
      expect(findings.map((f) => f.symbol), equals(['main', 'main=']));
    });

    test('ignores members, local functions and other declarations', () {
      const source = '''
class A {
  void a() {}
  static void b() {}
}
void main() {
  void local() {}
  local();
}
final x = () {};
typedef F = void Function();
''';
      expect(_tester.checkSource(rule, source), isEmpty);
    });
  });
}
