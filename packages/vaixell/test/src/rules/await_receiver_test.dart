import 'package:test/test.dart';
import 'package:vaixell/src/rules/await_receiver.dart';
import 'package:vaixell/src/violation/violation.dart';

import '../../helpers/parse.dart';

void main() {
  group(AwaitReceiverRule, () {
    const rule = AwaitReceiverRule();

    /// Returns the offsets of the findings for [statements] in the body of
    /// `Future<void> f() async`, relative to the start of the body.
    List<int> offsets(String statements) {
      const prefix = 'Future<void> f() async {\n';
      final findings = rule.check(parse('$prefix$statements\n}\n'));
      return [for (final f in findings) f.offset - prefix.length];
    }

    test('has the expected id', () {
      expect(rule.id, equals('await-receiver'));
    });

    test('defaults to warning', () {
      expect(rule.defaultSeverity, equals(Severity.warning));
    });

    test('flags an await used as a receiver', () {
      const source = '''
class Foo {
  Future<void> bar() async {
    (await f).x;
  }
}
''';
      final findings = rule.check(parse(source));
      expect(findings, hasLength(1));
      expect(findings.single.offset, equals(source.indexOf('await')));
      expect(findings.single.symbol, equals('Foo.bar@f'));
      expect(
        findings.single.message,
        equals(
          '`await` result is used as a receiver. '
          'Assign it to a local variable first.',
        ),
      );
    });

    for (final source in [
      '(await f).x;',
      '(await f)?.x;',
      '(await f).m();',
      '(await f)?.m();',
      '(await f)[i];',
      '(await f)?[i];',
      '(await f)!.x;',
      '(await f)..a();',
      '(await f)?..a();',
      '(await f)();',
      '(await f)<int>();',
      '((await f)).x;',
      '((await f) as T).x;',
      '(await f as T).x;',
      '((await f)! as T).x;',
      'x = (await f).y;',
      'g((await f).x);',
      'a && (await f).x;',
      'a ?? (await f).x;',
    ]) {
      test('flags `$source` once, at the await keyword', () {
        expect(offsets(source), equals([source.indexOf('await')]));
      });
    }

    for (final source in [
      'return (await f)!;',
      'g((await f)!);',
      '(await f)!;',
      'final v = (await f)! + 1;',
      'final v = (await f)!;',
      'final v = ((await f)!);',
      'final v = (await f)! as T;',
      'v = (await f)!;',
      'v ??= (await f)!;',
    ]) {
      test('flags the null check in `$source`', () {
        expect(offsets(source), equals([source.indexOf('await')]));
      });
    }

    test('flags `=> (await f)!`', () {
      expect(
        rule.check(parse('Future<int> f() async => (await g)!;\n')),
        hasLength(1),
      );
    });

    for (final source in [
      'final v = await f as T;',
      '(await f) as T;',
      'if (await f) {}',
      '!await f;',
      'g(await f);',
      'expect(await f, x);',
      'return await f;',
      '(await f) != null;',
      'await f.x;',
      'await f.m();',
      'x[await f];',
      'x?[await f];',
      'x.m(await f);',
      'x..m(await f);',
      'x..y = await f;',
    ]) {
      test('allows `$source`', () {
        expect(offsets(source), isEmpty);
      });
    }

    test('allows `=> await f`', () {
      expect(rule.check(parse('Future<int> f() async => await g;\n')), isEmpty);
    });

    test('flags nested awaits once each', () {
      const source = '(await (await f).g()).h;';
      expect(
        offsets(source),
        equals([source.indexOf('await'), source.lastIndexOf('await')]),
      );
    });

    test('names findings after the enclosing declaration', () {
      expect(
        rule
            .check(
              parse('''
Future<void> f() async {
  (await a).x;
  final g = () async => (await b).y;
}
class C {
  Future<void> m() async => (await c).z;
}
'''),
            )
            .map((f) => f.symbol),
        equals(['f@a', 'f@b', 'C.m@c']),
      );
    });

    test('qualifies findings with the name of what is awaited', () {
      expect(
        rule
            .check(
              parse('''
Future<void> f() async {
  (await a()).x;
  (await o.b()).x;
  (await o.c).x;
  (await o.p.d).x;
  (await e()()).x;
  (await (g)).x;
  (await (1 + 2)).x;
}
'''),
            )
            .map((f) => f.symbol),
        equals(['f@a', 'f@b', 'f@c', 'f@d', 'f@e', 'f@g', 'f']),
      );
    });

    test('qualifies findings outside any declaration', () {
      expect(
        rule
            .check(parse('@A(() async => (await a).x)\nlibrary;\n'))
            .single
            .symbol,
        equals('@a'),
      );
    });
  });
}
