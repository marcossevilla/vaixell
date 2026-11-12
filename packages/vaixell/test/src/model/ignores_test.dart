import 'package:test/test.dart';
import 'package:vaixell/src/model/model.dart';

Ignores _ignores(String content) =>
    Ignores.of(DartFile.parse(path: 'lib/a.dart', content: content));

void main() {
  group(Ignores, () {
    test('ignores nothing without ignore comments', () {
      final ignores = _ignores('// a comment\nclass A {}\n');
      expect(ignores.ignores('static-method', 1), isFalse);
      expect(ignores.ignores('static-method', 2), isFalse);
    });

    test('applies a comment alone on its line to the next line', () {
      final ignores = _ignores(
        'class A {\n  // ignore: rule\n  void f() {}\n}\n',
      );
      expect(ignores.ignores('rule', 3), isTrue);
      expect(ignores.ignores('rule', 2), isFalse);
      expect(ignores.ignores('rule', 4), isFalse);
    });

    test('applies a comment after code to its own line', () {
      final ignores = _ignores('class A {\n  void f() {} // ignore: rule\n}\n');
      expect(ignores.ignores('rule', 2), isTrue);
      expect(ignores.ignores('rule', 3), isFalse);
    });

    test('applies a comment on the first line to the second', () {
      final ignores = _ignores('// ignore: rule\nvoid f() {}\n');
      expect(ignores.ignores('rule', 2), isTrue);
    });

    test('applies a comment at the end of the file', () {
      final ignores = _ignores('void f() {} // ignore: rule\n');
      expect(ignores.ignores('rule', 1), isTrue);
    });

    test('reads comma-separated ids, with or without spaces', () {
      final ignores = _ignores(
        '// ignore: avoid_print, rule-a,rule-b ,\nvoid f() {}\n',
      );
      expect(ignores.ignores('avoid_print', 2), isTrue);
      expect(ignores.ignores('rule-a', 2), isTrue);
      expect(ignores.ignores('rule-b', 2), isTrue);
      expect(ignores.ignores('', 2), isFalse);
    });

    test('ignores only the ids it names', () {
      final ignores = _ignores('// ignore: rule-a\nvoid f() {}\n');
      expect(ignores.ignores('rule-b', 2), isFalse);
    });

    test('accepts no space after the slashes', () {
      final ignores = _ignores('//ignore: rule\nvoid f() {}\n');
      expect(ignores.ignores('rule', 2), isTrue);
    });

    test('skips doc comments, block comments and strings', () {
      final ignores = _ignores('''
/// ignore: rule
void f() {}
/* ignore: rule */
void g() {}
const s = '// ignore: rule';
void h() {}
''');
      expect(ignores.ignores('rule', 2), isFalse);
      expect(ignores.ignores('rule', 4), isFalse);
      expect(ignores.ignores('rule', 5), isFalse);
      expect(ignores.ignores('rule', 6), isFalse);
    });

    test('applies ignore_for_file to every line, wherever it is', () {
      for (final source in [
        '// ignore_for_file: rule\nvoid f() {}\nvoid g() {}\n',
        'void f() {}\nvoid g() {}\n// ignore_for_file: rule\n',
        'void f() {} // ignore_for_file: rule\nvoid g() {}\n',
      ]) {
        final ignores = _ignores(source);
        expect(ignores.ignores('rule', 1), isTrue, reason: source);
        expect(ignores.ignores('rule', 3), isTrue, reason: source);
        expect(ignores.ignores('other', 1), isFalse, reason: source);
      }
    });

    test('reads comma-separated ids in ignore_for_file', () {
      final ignores = _ignores('//ignore_for_file: a,  b ,\n');
      expect(ignores.ignores('a', 1), isTrue);
      expect(ignores.ignores('b', 1), isTrue);
      expect(ignores.ignores('', 1), isFalse);
    });

    test('does not read ignore_for_file as an ignore', () {
      final ignores = _ignores('// ignore_for_file\nvoid f() {}\n');
      expect(ignores.ignores('_for_file', 2), isFalse);
    });

    test('is the same object for the same file', () {
      final file = DartFile.parse(path: 'lib/a.dart', content: '');
      expect(Ignores.of(file), same(Ignores.of(file)));
    });
  });
}
