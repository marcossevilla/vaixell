import 'package:test/test.dart';
import 'package:vaixell/src/rules/parse_error.dart';

import '../helpers/parse.dart';

void main() {
  group(ParseErrorRule, () {
    const rule = ParseErrorRule();

    test('has the expected id and runs on broken files', () {
      expect(rule.id, equals('parse-error'));
      expect(rule.checksFilesWithErrors, isTrue);
    });

    test('ignores files without syntax errors', () {
      expect(rule.check(parse('class A {}\n')), isEmpty);
    });

    test('reports one finding for the file at the first error', () {
      final findings = rule.check(parse('class A {\n'));
      expect(findings, hasLength(1));
      expect(findings.single.symbol, isNull);
      expect(findings.single.message, startsWith('Syntax error: '));
      expect(findings.single.message, isNot(contains('more)')));
    });

    test('mentions how many more errors there are', () {
      final findings = rule.check(parse('class A { void f( }\nclass {\n'));
      expect(findings.single.message, matches(r'\(and \d+ more\)$'));
    });
  });
}
