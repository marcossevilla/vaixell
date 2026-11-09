import 'package:test/test.dart';
import 'package:vaixell/src/rules/throwaway_instance.dart';
import 'package:vaixell/src/violation/violation.dart';
import 'package:vaixell/testing.dart';

const _tester = RuleTester();

void main() {
  group(ThrowawayInstanceRule, () {
    const rule = ThrowawayInstanceRule();

    List<String?> symbols(String source) => [
      for (final finding in _tester.checkSource(rule, source)) finding.symbol,
    ];

    test('has the expected id and severity', () {
      expect(rule.id, equals('throwaway-instance'));
      expect(rule.defaultSeverity, Severity.warning);
    });

    test('flags a const instance used for one call', () {
      const source = 'void f(List<int> a) => const Ids().check(a);\n';
      final findings = _tester.checkSource(rule, source);
      expect(findings.single.symbol, equals('f@check'));
      expect(findings.single.offset, equals(source.indexOf('const')));
      expect(
        findings.single.message,
        equals(
          'An instance is created only to use `check` on it. Move `check` '
          'to the type whose data it works on, or take the instance as a '
          'dependency.',
        ),
      );
    });

    test('flags new, named and implicit constructors', () {
      expect(
        symbols('''
void f() {
  new A().a();
  const B.named().b();
  C().c();
  _D().d();
}
'''),
        ['f@a', 'f@b', 'f@c', 'f@d'],
      );
    });

    test('flags getters, null-aware access and parentheses', () {
      expect(
        symbols('''
void f() {
  const A().a;
  const B()?.b();
  (const C()).c;
}
'''),
        ['f@a', 'f@b', 'f@c'],
      );
    });

    test('allows constructors with arguments', () {
      const source = '''
void f(String path) {
  File(path).readAsStringSync();
  const Duration(seconds: 1).inMilliseconds;
}
''';
      expect(symbols(source), isEmpty);
    });

    test('allows cascades', () {
      const source = 'void f() => StringBuffer()..write(1)..toString();\n';
      expect(symbols(source), isEmpty);
    });

    test('allows static methods and factories, which look the same', () {
      const source = 'void f() => DateTime.now().year;\n';
      expect(symbols(source), isEmpty);
    });

    test('allows function calls and kept instances', () {
      const source = r'''
void f() {
  build().run();
  _$build().run();
  $().run();
  final parser = const Parser();
  parser.parse();
  run();
}
''';
      expect(symbols(source), isEmpty);
    });
  });
}
