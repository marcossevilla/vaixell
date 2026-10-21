import 'package:test/test.dart';
import 'package:vaixell/src/rules/raw_json.dart';

import '../helpers/parse.dart';

void main() {
  group(RawJsonRule, () {
    const rule = RawJsonRule();

    List<String?> symbols(String source, {String path = 'lib/a.dart'}) =>
        rule.check(parse(source, path: path)).map((f) => f.symbol).toList();

    test('has the expected id', () {
      expect(rule.id, equals('raw-json'));
    });

    test('flags jsonDecode and jsonEncode calls', () {
      final findings = rule.check(
        parse('''
void f(String s) {
  jsonDecode(s);
  jsonEncode({'a': s});
}
'''),
      );
      expect(findings.map((f) => f.symbol), equals(['f@decode', 'f@encode']));
      expect(findings.first.offset, equals(21));
      expect(
        findings.first.message,
        equals(
          '`jsonDecode` is not allowed outside model classes. '
          'Deserialize JSON in a `fromJson` constructor.',
        ),
      );
      expect(
        findings.last.message,
        equals(
          '`jsonEncode` is not allowed outside model classes. '
          'Serialize JSON in a `toJson` method.',
        ),
      );
    });

    test('flags json.decode and json.encode, with or without a prefix', () {
      final findings = rule.check(
        parse('''
void f(String s) {
  json.decode(s);
  convert.json.encode([s]);
  convert.jsonDecode(s);
}
'''),
      );
      expect(
        findings.map((f) => f.symbol),
        equals(['f@decode', 'f@encode', 'f@decode']),
      );
      expect(findings.map((f) => f.message), [
        startsWith('`json.decode` is not allowed'),
        startsWith('`json.encode` is not allowed'),
        startsWith('`jsonDecode` is not allowed'),
      ]);
    });

    test('ignores other calls named decode, encode or jsonDecode', () {
      expect(
        symbols('''
void f(String s) {
  utf8.decode(s);
  base64.encode(s);
  a.b.jsonDecode(s);
  decode(s);
  print(s);
}
'''),
        isEmpty,
      );
    });

    test('flags Map<String, dynamic> wherever it is written', () {
      final findings = rule.check(
        parse('''
Map<String, dynamic>? f(Object o) {
  final a = o as Map<String, dynamic>;
  final b = <List<Map<String, dynamic>>>[];
  return null;
}
'''),
      );
      expect(
        findings.map((f) => f.symbol),
        equals(['f@map', 'f@map', 'f@map']),
      );
      expect(
        findings.first.message,
        equals(
          '`Map<String, dynamic>` is not allowed outside model classes. '
          'Use a model class with `fromJson` and `toJson`.',
        ),
      );
    });

    test('ignores other map types', () {
      expect(
        symbols('''
Map<String, Object?> a = {};
Map<String, int> b = {};
Map<int, dynamic> c = {};
Map d = {};
Map<String, dynamic, int> e = {};
HashMap<String, dynamic> f = {};
'''),
        isEmpty,
      );
    });

    test('allows fromJson constructors and methods and toJson methods', () {
      expect(
        symbols('''
class A {
  A.fromJson(Map<String, dynamic> json) : this.x = jsonDecode('');
  factory fromJson2(Map<String, dynamic> json) => A();
  static A fromJson(String s) => A.fromJson(jsonDecode(s));
  String toJson() => jsonEncode(<String, dynamic>{});
}
class B {
  factory fromJson(Map<String, dynamic> json) => B();
}
'''),
        equals(['A.fromJson2@map']),
      );
    });

    test('allows JSON passed straight to fromJson', () {
      expect(
        symbols('''
void f(String s, Object o) {
  User.fromJson(jsonDecode(s));
  User.fromJson(jsonDecode(s) as Map<String, dynamic>);
  User.fromJson((json.decode(s) as Map<String, dynamic>));
  User.fromJson(o as Map<String, dynamic>);
  new User.fromJson(jsonDecode(s) as Map<String, dynamic>);
  api.User.fromJson(jsonDecode(s));
}
'''),
        isEmpty,
      );
    });

    test('flags JSON that only passes near fromJson', () {
      expect(
        symbols('''
void f(String s) {
  User.toJsonX(jsonDecode(s));
  new User(jsonDecode(s) as Map<String, dynamic>);
  User.fromJson(wrap(jsonDecode(s)));
  User.fromJson(jsonDecode(s) as List<Map<String, dynamic>>);
  final m = jsonDecode(s) as Map<String, dynamic>;
  User.fromJson(m);
}
'''),
        equals([
          'f@decode',
          'f@decode',
          'f@map',
          'f@decode',
          'f@map',
          'f@decode',
          'f@map',
        ]),
      );
    });

    test('allows encoding a value that is not a collection literal', () {
      expect(
        symbols('''
void f(User user) {
  jsonEncode(user);
  json.encode(user.settings);
  jsonEncode((user));
}
'''),
        isEmpty,
      );
    });

    test('flags encoding collection literals', () {
      expect(
        symbols('''
void f(String s) {
  jsonEncode({'a': s});
  jsonEncode(<Object?>[s]);
  json.encode(({'a': s}));
  jsonEncode();
  jsonEncode(toEncodable: s);
}
'''),
        equals(['f@encode', 'f@encode', 'f@encode', 'f@encode', 'f@encode']),
      );
    });

    test('allows files under a models directory', () {
      const source = 'final a = jsonDecode("");\n';
      expect(symbols(source, path: 'lib/models/a.dart'), isEmpty);
      expect(symbols(source, path: 'lib/src/models/user/a.dart'), isEmpty);
      expect(symbols(source, path: 'lib/models.dart'), hasLength(1));
      expect(symbols(source, path: 'lib/src/models_x/a.dart'), hasLength(1));
    });

    test('names findings after the enclosing declaration', () {
      expect(
        symbols('''
final top = jsonDecode('');
Map<String, dynamic> a = {}, b = {};
void function() => jsonDecode('');
class C {
  C() { jsonDecode(''); }
  C.named() { jsonDecode(''); }
  final Map<String, dynamic> field = {};
  final other = jsonDecode('');
  void method() {
    void local() => jsonDecode('');
    final x = () => jsonDecode('');
  }
}
mixin M { void m() => jsonDecode(''); }
enum E { a; void m() => jsonDecode(''); }
extension X on int { void m() => jsonDecode(''); }
extension on int { void m() => jsonDecode(''); }
extension type T(int v) { void m() => jsonDecode(''); }
'''),
        equals([
          'top@decode',
          'a@map',
          'function@decode',
          'C.new@decode',
          'C.named@decode',
          'C.field@map',
          'C.other@decode',
          'C.method@decode',
          'C.method@decode',
          'M.m@decode',
          'E.m@decode',
          'X.m@decode',
          '<unnamed>.m@decode',
          'T.m@decode',
        ]),
      );
    });

    test('uses only the kind outside any declaration', () {
      final file = parse("@Foo(jsonDecode(''))\nlibrary;\n");
      expect(file.hasErrors, isFalse);
      expect(rule.check(file).map((f) => f.symbol), equals(['@decode']));
    });
  });
}
