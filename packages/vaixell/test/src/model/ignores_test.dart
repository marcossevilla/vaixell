import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:vaixell/src/model/model.dart';

final class _MockDartFile extends Mock implements DartFile;

Ignores _ignores(String content) =>
    Ignores.of(DartFile.parse(path: 'lib/a.dart', content: content));

void main() {
  group(Ignores, () {
    test('ignores nothing without ignore comments', () {
      final ignores = _ignores('// a comment\nclass A {}\n');
      expect(ignores.turnsOff('static-method', line: 1), isFalse);
      expect(ignores.turnsOff('static-method', line: 2), isFalse);
    });

    test('ignores nothing in a file that does not come from parse', () {
      final ignores = Ignores.of(_MockDartFile());
      expect(ignores.turnsOff('rule', line: 1), isFalse);
      expect(ignores.turnsOffFile('rule'), isFalse);
    });

    test('applies a comment alone on its line to the next line', () {
      final ignores = _ignores(
        'class A {\n  // ignore: rule\n  void f() {}\n}\n',
      );
      expect(ignores.turnsOff('rule', line: 3), isTrue);
      expect(ignores.turnsOff('rule', line: 2), isFalse);
      expect(ignores.turnsOff('rule', line: 4), isFalse);
    });

    test('applies a comment after code to its own line', () {
      final ignores = _ignores('class A {\n  void f() {} // ignore: rule\n}\n');
      expect(ignores.turnsOff('rule', line: 2), isTrue);
      expect(ignores.turnsOff('rule', line: 3), isFalse);
    });

    test('applies a comment on the first line to the second', () {
      final ignores = _ignores('// ignore: rule\nvoid f() {}\n');
      expect(ignores.turnsOff('rule', line: 2), isTrue);
    });

    test('applies a comment at the end of the file', () {
      final ignores = _ignores('void f() {} // ignore: rule\n');
      expect(ignores.turnsOff('rule', line: 1), isTrue);
    });

    test('applies a comment only to the line right below it', () {
      final ignores = _ignores('// ignore: rule\n\nvoid f() {}\n');
      expect(ignores.turnsOff('rule', line: 2), isTrue);
      expect(ignores.turnsOff('rule', line: 3), isFalse);
    });

    test('does not combine stacked comments', () {
      final ignores = _ignores(
        '// ignore: rule-a\n// ignore: rule-b\nvoid f() {}\n',
      );
      expect(ignores.turnsOff('rule-a', line: 2), isTrue);
      expect(ignores.turnsOff('rule-a', line: 3), isFalse);
      expect(ignores.turnsOff('rule-b', line: 3), isTrue);
    });

    test('reads a comment alone on its line after tabs', () {
      final ignores = _ignores(
        'class A {\n\t// ignore: rule\n\tvoid f() {}\n}\n',
      );
      expect(ignores.turnsOff('rule', line: 3), isTrue);
    });

    test('reads lines with CRLF endings', () {
      final ignores = _ignores(
        'class A {\r\n  // ignore: rule\r\n  void f() {}\r\n'
        '  void g() {} // ignore: other\r\n}\r\n',
      );
      expect(ignores.turnsOff('rule', line: 3), isTrue);
      expect(ignores.turnsOff('other', line: 4), isTrue);
      expect(ignores.turnsOff('other', line: 5), isFalse);
    });

    test('reads a comment inside a multi-line expression', () {
      final ignores = _ignores('''
final x = [
  // ignore: rule
  1,
  2, // ignore: other
];
''');
      expect(ignores.turnsOff('rule', line: 3), isTrue);
      expect(ignores.turnsOff('other', line: 4), isTrue);
    });

    test('reads comma-separated ids, with or without spaces', () {
      final ignores = _ignores(
        '// ignore: avoid_print, rule-a,rule-b ,\nvoid f() {}\n',
      );
      expect(ignores.turnsOff('avoid_print', line: 2), isTrue);
      expect(ignores.turnsOff('rule-a', line: 2), isTrue);
      expect(ignores.turnsOff('rule-b', line: 2), isTrue);
      expect(ignores.turnsOff('', line: 2), isFalse);
    });

    test('skips text after the ids', () {
      for (final comment in [
        '// ignore: rule-a, rule-b // a framework requires it',
        '// ignore: rule-a, rule-b a framework requires it',
        '// ignore: rule-a, rule-b (a framework requires it)',
      ]) {
        final ignores = _ignores('$comment\nvoid f() {}\n');
        expect(ignores.turnsOff('rule-a', line: 2), isTrue, reason: comment);
        expect(ignores.turnsOff('rule-b', line: 2), isTrue, reason: comment);
      }
    });

    test('ignores nothing when no id follows the colon', () {
      final ignores = _ignores('// ignore: , rule\nvoid f() {}\n');
      expect(ignores.turnsOff('rule', line: 2), isFalse);
    });

    test('ignores only the ids it names', () {
      final ignores = _ignores('// ignore: rule-a\nvoid f() {}\n');
      expect(ignores.turnsOff('rule-b', line: 2), isFalse);
    });

    test('matches ids case-sensitively', () {
      final ignores = _ignores('// ignore: Rule\nvoid f() {}\n');
      expect(ignores.turnsOff('rule', line: 2), isFalse);
    });

    test('accepts no space after the slashes', () {
      final ignores = _ignores('//ignore: rule\nvoid f() {}\n');
      expect(ignores.turnsOff('rule', line: 2), isTrue);
    });

    test('skips doc comments', () {
      final ignores = _ignores('/// ignore: rule\nvoid f() {}\n');
      expect(ignores.turnsOff('rule', line: 2), isFalse);
    });

    test('skips block comments', () {
      final ignores = _ignores('/* ignore: rule */\nvoid f() {}\n');
      expect(ignores.turnsOff('rule', line: 2), isFalse);
    });

    test('skips strings', () {
      final ignores = _ignores("const s = '// ignore: rule';\nvoid f() {}\n");
      expect(ignores.turnsOff('rule', line: 1), isFalse);
      expect(ignores.turnsOff('rule', line: 2), isFalse);
    });

    test('applies ignore_for_file to every line, wherever it is', () {
      for (final source in [
        '// ignore_for_file: rule\nvoid f() {}\nvoid g() {}\n',
        'void f() {}\nvoid g() {}\n// ignore_for_file: rule\n',
        'void f() {} // ignore_for_file: rule\nvoid g() {}\n',
      ]) {
        final ignores = _ignores(source);
        expect(ignores.turnsOffFile('rule'), isTrue, reason: source);
        expect(ignores.turnsOff('rule', line: 1), isTrue, reason: source);
        expect(ignores.turnsOff('rule', line: 3), isTrue, reason: source);
        expect(ignores.turnsOffFile('other'), isFalse, reason: source);
      }
    });

    test('reads comma-separated ids in ignore_for_file', () {
      final ignores = _ignores('//ignore_for_file: a,  b , // why\n');
      expect(ignores.turnsOffFile('a'), isTrue);
      expect(ignores.turnsOffFile('b'), isTrue);
      expect(ignores.turnsOffFile(''), isFalse);
    });

    test('does not turn off a whole file with a line ignore', () {
      final ignores = _ignores('// ignore: rule\nvoid f() {}\n');
      expect(ignores.turnsOffFile('rule'), isFalse);
    });

    test('does not read ignore_for_file without a colon', () {
      final ignores = _ignores('// ignore_for_file rule\nvoid f() {}\n');
      expect(ignores.turnsOffFile('rule'), isFalse);
      expect(ignores.turnsOff('rule', line: 2), isFalse);
    });
  });
}
