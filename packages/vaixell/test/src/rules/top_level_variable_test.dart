import 'package:test/test.dart';
import 'package:vaixell/src/rules/top_level_variable.dart';
import 'package:vaixell/testing.dart';

const _tester = RuleTester();

void main() {
  group(TopLevelVariableRule, () {
    const rule = TopLevelVariableRule();

    test('has the expected id', () {
      expect(rule.id, equals('top-level-variable'));
    });

    test('flags final, var, const, late and typed variables', () {
      final findings = _tester.checkSource(rule, '''
final a = 1;
var b = 2;
const c = 3;
late final int d;
int? e;
String _f = '';
''');
      expect(
        findings.map((f) => f.symbol),
        equals(['a', 'b', 'c', 'd', 'e', '_f']),
      );
      expect(findings.first.offset, equals(6));
    });

    test('flags every variable in a declaration list', () {
      final findings = _tester.checkSource(rule, 'var a = 1, b = 2;\n');
      expect(findings.map((f) => f.symbol), equals(['a', 'b']));
    });

    test('says constant for const declarations', () {
      final findings = _tester.checkSource(
        rule,
        'const a = 1;\nfinal b = 2;\n',
      );
      expect(findings.map((f) => f.message), [
        'Top-level constant `a` is not allowed. Move it into a class.',
        'Top-level variable `b` is not allowed. Move it into a class.',
      ]);
    });

    test('ignores fields, locals and functions', () {
      const source = '''
class A {
  static const a = 1;
  final b = 2;
}
void main() {
  final c = 3;
}
''';
      expect(_tester.checkSource(rule, source), isEmpty);
    });
  });
}
