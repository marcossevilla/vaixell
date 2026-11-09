import 'package:test/test.dart';
import 'package:vaixell/src/rules/extension_declaration.dart';
import 'package:vaixell/testing.dart';

const _tester = RuleTester();

void main() {
  group(ExtensionDeclarationRule, () {
    const rule = ExtensionDeclarationRule();

    test('has the expected id', () {
      expect(rule.id, equals('extension-declaration'));
    });

    test('flags named extensions on a type the file declares', () {
      const source = 'class User {}\nextension UserX on User {}\n';
      final findings = _tester.checkSource(rule, source);
      expect(findings.single.symbol, equals('UserX'));
      expect(findings.single.offset, equals(source.indexOf('UserX')));
      expect(
        findings.single.message,
        equals(
          'Extension `UserX` adds members to `User`, which this file '
          'declares. Add them to `User` instead.',
        ),
      );
    });

    test('flags unnamed extensions at the extension keyword', () {
      const source = 'enum Kind { a }\nextension on Kind {}\n';
      final findings = _tester.checkSource(rule, source);
      expect(findings.single.symbol, equals('<unnamed>'));
      expect(findings.single.offset, equals(source.indexOf('extension')));
      expect(
        findings.single.message,
        equals(
          'This extension adds members to `Kind`, which this file declares. '
          'Add them to `Kind` instead.',
        ),
      );
    });

    test('flags extensions on mixins, extension types and generic types', () {
      const source = '''
mixin M {}
extension type Id(int value) {}
class Box<T> {}
extension MX on M {}
extension IdX on Id {}
extension BoxX<T> on Box<T> {}
''';
      expect(_tester.checkSource(rule, source).map((f) => f.symbol), [
        'MX',
        'IdX',
        'BoxX',
      ]);
    });

    test('allows extensions on types the file does not declare', () {
      const source = '''
extension StringX on String {}
extension on List<int> {}
extension FX on void Function() {}
''';
      expect(_tester.checkSource(rule, source), isEmpty);
    });

    test('allows extensions on imported types with the same name', () {
      const source = '''
import 'dart:core' as core;
class String {}
extension StringX on core.String {}
''';
      expect(_tester.checkSource(rule, source), isEmpty);
    });

    test('does not count extensions as declared types', () {
      const source = 'extension A on int {}\nextension B on A {}\n';
      expect(_tester.checkSource(rule, source), isEmpty);
    });

    test('allows extension types', () {
      const source = 'extension type UserId(String value) {}\n';
      expect(_tester.checkSource(rule, source), isEmpty);
    });
  });
}
