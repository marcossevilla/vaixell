import 'package:test/test.dart';
import 'package:theseus_cli/src/rules/extension_declaration.dart';

import '../helpers/parse.dart';

void main() {
  group(ExtensionDeclarationRule, () {
    const rule = ExtensionDeclarationRule();

    test('has the expected id', () {
      expect(rule.id, equals('extension-declaration'));
    });

    test('flags named extensions', () {
      final findings = rule.check(parse('extension StringX on String {}\n'));
      expect(findings.single.symbol, equals('StringX'));
      expect(findings.single.offset, equals(10));
      expect(
        findings.single.message,
        equals('Extension `StringX` is not allowed. Use a class instead.'),
      );
    });

    test('flags unnamed extensions at the extension keyword', () {
      final findings = rule.check(
        parse('class A {}\nextension on String {}\n'),
      );
      expect(findings.single.symbol, equals('<unnamed>'));
      expect(findings.single.offset, equals(11));
      expect(
        findings.single.message,
        equals('Unnamed extensions are not allowed. Use a class instead.'),
      );
    });

    test('flags extension types', () {
      final findings = rule.check(parse('extension type Id(int value) {}\n'));
      expect(findings.single.symbol, equals('Id'));
      expect(
        findings.single.message,
        equals('Extension type `Id` is not allowed. Use a class instead.'),
      );
    });

    test('ignores classes, mixins and enums', () {
      final file = parse('class A {}\nmixin M {}\nenum E { a }\n');
      expect(rule.check(file), isEmpty);
    });
  });
}
