import 'package:test/test.dart';
import 'package:vaixell/src/model/model.dart';

DartFile _parse(String source) =>
    const DartFileParser().parse(path: 'lib/a.dart', content: source);

List<Expression> _expressions(String source) => _parse(source).expressions;

/// The first expression of type [T] in [source].
T _first<T extends Expression>(String source) =>
    _expressions(source).whereType<T>().first;

void main() {
  group(Expression, () {
    group('in DartFile.expressions', () {
      test('are every expression in source order', () {
        final expressions = _expressions('f() { g(a + 1, () => b); }');
        expect(expressions.map((e) => e.runtimeType.toString()), [
          contains('MethodCall'),
          contains('Other'),
          contains('Identifier'),
          contains('Other'),
          contains('Other'),
          contains('Identifier'),
        ]);
        final offsets = expressions.map((e) => e.offset).toList();
        expect(offsets, orderedEquals([...offsets]..sort()));
      });

      test('leave out names that are part of a larger node', () {
        final names = [
          for (final expression in _expressions('''
@A.b(c)
f() {
  a.m();
  a.p;
  a?.q;
  new B.n();
  const C();
}
'''))
            if (expression case Reference(:final name, target: null)) name,
        ];
        expect(names, ['c', 'a', 'a', 'a']);
      });

      test('leave out the names in constructors and dot shorthands', () {
        final expressions = _expressions('''
enum E { a.named(1); const E.named(int x); }
class C extends B {
  final int f;
  C(int x) : f = x, super.named();
  C.other() : this(0);
  C.redirect() : this.other();
}
E g() => .named(.c, .d(), const .e());
''');
        expect(
          [
            for (final expression in expressions)
              if (expression is Reference) expression.name,
          ],
          ['x'],
        );
      });

      test('leave out directives, doc comment references and labels', () {
        final expressions = _expressions('''
library a.b;
import 'a.dart' if (dart.library.io) 'b.dart' show x hide y;
export 'c.dart';
part 'd.dart';
/// Calls [z].
f() { l: for (;;) { break l; } }
void g() { void h() {} }
''');
        expect(expressions, isEmpty);
      });

      test('keep the same objects on every read', () {
        final file = _parse('f() => a.m();');
        final call = file.expressions.first as MethodCall;
        expect(call.target, same(file.expressions[1]));
        expect(file.expressions, same(file.expressions));
      });
    });

    group(Await, () {
      test('has its operand', () {
        final await = _first<Await>('f() async { await g(); }');
        expect(await.operand, isA<MethodCall>());
      });
    });

    group(MethodCall, () {
      test('has a name and no target when called directly', () {
        final call = _first<MethodCall>('f() { g(1, n: 2); }');
        expect(call.name, 'g');
        expect(call.target, isNull);
        expect(call.operator, isNull);
        expect(call.arguments.map((a) => (a.name, a.value.offset)), [
          (null, 'f() { g('.length),
          ('n', 'f() { g(1, n: '.length),
        ]);
      });

      test('has a target and an operator', () {
        const source = 'f() { a.m(); a?.n(); }';
        final calls = _expressions(source).whereType<MethodCall>().toList();
        expect(calls.map((c) => (c.name, c.operator)), [
          ('m', AccessOperator.period),
          ('n', AccessOperator.questionPeriod),
        ]);
        expect((calls.first.target! as Reference).name, 'a');
      });

      test("has the cascade's target in a cascade", () {
        const source = 'f() { x..m(); x?..n(); }';
        final calls = _expressions(source).whereType<MethodCall>().toList();
        expect(calls.map((c) => (c.name, c.operator)), [
          ('m', AccessOperator.cascade),
          ('n', AccessOperator.questionCascade),
        ]);
        expect(calls.map((c) => (c.target! as Reference).name), ['x', 'x']);
      });

      test('include constructor calls without new', () {
        final call = _first<MethodCall>('f() => User.fromJson(j);');
        expect(call.name, 'fromJson');
        expect((call.target! as Reference).name, 'User');
      });
    });

    group(InstanceCreation, () {
      test('has the last name before the arguments', () {
        final names = [
          for (final expression in _expressions(
            'f() { new User.fromJson(j); const User(); new p.User(); }',
          ))
            if (expression case InstanceCreation(:final name)) name,
        ];
        expect(names, ['fromJson', 'User', 'User']);
      });

      test('has its arguments', () {
        final creation = _first<InstanceCreation>('f() => new A(1);');
        expect(creation.arguments.single.value, isA<OtherExpression>());
      });
    });

    group(FunctionCall, () {
      test('has its callee and arguments', () {
        final call = _first<FunctionCall>('f() { (g)(1); }');
        expect(call.callee, isA<Parenthesized>());
        expect(call.arguments, hasLength(1));
      });
    });

    group(Reference, () {
      test('is a plain name', () {
        final reference = _first<Reference>('f() => a;');
        expect(reference.name, 'a');
        expect(reference.target, isNull);
        expect(reference.operator, isNull);
      });

      test('is a prefixed name', () {
        final reference = _first<Reference>('f() => a.b;');
        expect(reference.name, 'b');
        expect((reference.target! as Reference).name, 'a');
        expect(reference.operator, AccessOperator.period);
      });

      test('is a property access', () {
        const source = 'f() { a?.b; (a).c; x..d; }';
        final references = _expressions(source)
            .whereType<Reference>()
            .where((r) => r.target != null)
            .toList();
        expect(references.map((r) => (r.name, r.operator)), [
          ('b', AccessOperator.questionPeriod),
          ('c', AccessOperator.period),
          ('d', AccessOperator.cascade),
        ]);
        expect(references[1].target, isA<Parenthesized>());
        expect((references[2].target! as Reference).name, 'x');
      });
    });

    group('other forms', () {
      const source = 'f() { (a as T); a!; this; [1]; x = {}; <int>{}; 1; }';
      final expressions = _expressions(source);

      test('are casts, with their operand and type', () {
        final cast = expressions.whereType<Cast>().single;
        expect((cast.operand as Reference).name, 'a');
        expect(cast.type.name, 'T');
      });

      test('are null checks, with their operand', () {
        final check = expressions.whereType<NullCheck>().single;
        expect((check.operand as Reference).name, 'a');
      });

      test('are this, collection literals and other expressions', () {
        expect(expressions.whereType<This>(), hasLength(1));
        expect(expressions.whereType<CollectionLiteral>(), hasLength(3));
        expect(expressions.whereType<OtherExpression>(), isNotEmpty);
      });

      test('are parenthesized expressions', () {
        final parenthesized = expressions.whereType<Parenthesized>().single;
        expect(parenthesized.expression, isA<Cast>());
        expect(parenthesized.unparenthesized, isA<Cast>());
      });

      test('are unparenthesized through every pair of parentheses', () {
        final outer = _first<Parenthesized>('f() => ((a));');
        expect(outer.unparenthesized, isA<Reference>());
        expect(outer.expression.unparenthesized, isA<Reference>());
        expect(
          outer.unparenthesized.unparenthesized,
          same(outer.unparenthesized),
        );
      });
    });
  });

  group(Use, () {
    Use useOf(String source, String text, {DartFile? file}) =>
        (file ?? _parse(source)).expressions
            .firstWhere((e) => e.offset == source.indexOf(text))
            .use;

    test('is a receiver use for targets and callees', () {
      const sources = [
        'f() async => (await g).x;',
        'f() async => (await g)?.x;',
        'f() async => (await g).m();',
        'f() async => (await g)[0];',
        'f() async => (await g)..m();',
        'f() async => (await g)();',
        'f() async => ((await g) as T).x;',
        'f() async => ((await g)).x;',
      ];
      for (final source in sources) {
        expect(useOf(source, 'await'), isA<ReceiverUse>(), reason: source);
      }
    });

    test('is a null check use for the operand of !', () {
      expect(useOf('f() async => (await g)!;', 'await'), isA<NullCheckUse>());
    });

    test('is an argument use of the call', () {
      const source = 'f() { g(v1, n: v2); new A(v3); h()(v4); g((v5 as T)); }';
      final file = _parse(source);
      final calls = file.expressions.whereType<Call>().toList();
      final uses = [
        for (final name in ['v1', 'v2', 'v3', 'v4', 'v5'])
          useOf(source, name, file: file) as ArgumentUse,
      ];
      expect(uses.map((u) => u.name), [null, 'n', null, null, null]);
      expect(uses.map((u) => u.call), [
        same(calls[0]),
        same(calls[0]),
        same(calls[1]),
        same(calls[2]),
        same(calls[4]),
      ]);
    });

    test('is another use everywhere else', () {
      const sources = [
        'f() => v1;',
        'f() { v1 as T; }',
        '@A(v1) f() {}',
        '@A(n: v1) f() {}',
        'class C { C() : super(v1); }',
        'f() { x.y = v1; }',
      ];
      for (final source in sources) {
        expect(useOf(source, 'v1'), isA<OtherUse>(), reason: source);
      }
    });
  });

  group(Enclosed, () {
    ({Declaration? declaration, Member? member, String? symbol}) whereIs(
      String source,
      String text, {
      DartFile? file,
    }) {
      final expression = (file ?? _parse(source)).expressions.firstWhere(
        (e) => e.offset == source.indexOf(text),
      );
      return (
        declaration: expression.declaration,
        member: expression.member,
        symbol: expression.symbol,
      );
    }

    test('is in a member of a declaration', () {
      const source = '''
class C {
  C() : x = a;
  int x = b;
  void m() => c;
  set s(int v) => d;
}
''';
      final file = _parse(source);
      final type = file.declarations.single as TypeDeclaration;
      expect(
        [
          for (final text in ['a;', 'b;', 'c;', 'd;'])
            whereIs(source, text, file: file),
        ],
        [
          (declaration: type, member: type.members[0], symbol: 'C.new'),
          (declaration: type, member: type.members[1], symbol: 'C.x'),
          (declaration: type, member: type.members[2], symbol: 'C.m'),
          (declaration: type, member: type.members[3], symbol: 'C.s='),
        ],
      );
    });

    test('is in a primary constructor, in its header or its body', () {
      const source = '''
class const C.named(final int x = a) {
  this : assert(x > b);
}
''';
      final file = _parse(source);
      final type = file.declarations.single as TypeDeclaration;
      final constructor = type.constructors.single;
      expect(
        [
          for (final text in ['a)', 'b)']) whereIs(source, text, file: file),
        ],
        [
          for (var i = 0; i < 2; i++)
            (declaration: type, member: constructor, symbol: 'C.named'),
        ],
      );
    });

    test('is in a declaration without a member', () {
      const source = '''
@A(a)
class C { @B(b) int x = 1, y = 2; }
enum E { v(c) }
void f() => d;
set s(int v) => e;
final g = h;
''';
      final symbols = [
        for (final text in ['a)', 'b)', 'c)', 'd;', 'e;', 'h;'])
          whereIs(source, text),
      ];
      expect(symbols.map((w) => w.member), everyElement(isNull));
      expect(symbols.map((w) => w.symbol), ['C', 'C', 'E', 'f', 's=', 'g']);
    });

    test('is outside any declaration', () {
      const source = '''
@A(a)
library;
@B(b)
final x = 1;
typedef T = List<int>;
''';
      final file = _parse(source);
      for (final text in ['a)', 'b)']) {
        final where = whereIs(source, text);
        expect(where.declaration, isNull);
        expect(where.member, isNull);
        expect(where.symbol, isNull);
      }
      final type = file.typeAnnotations.first;
      expect(type.declaration, isNull);
      expect(type.symbol, isNull);
    });

    test('belongs to the first variable when it is shared', () {
      const source = '''
Map<String, dynamic> a = {}, b = {};
class C { Map<String, dynamic> c = {}, d = {}; }
''';
      expect(_parse(source).typeAnnotations.map((t) => t.symbol), [
        'a',
        'a',
        'a',
        'C.c',
        'C.c',
        'C.c',
      ]);
    });

    test('is in the declaration around local functions', () {
      const source = 'class C { void m() { void g() => a; } }';
      expect(whereIs(source, 'a;').symbol, 'C.m');
    });
  });

  group('returnExpression', () {
    List<Expression?> returnsOf(String source) => [
      for (final member
          in (_parse(source).declarations.single as TypeDeclaration).members)
        switch (member) {
          Method(:final returnExpression) => returnExpression,
          Constructor(:final returnExpression) => returnExpression,
          Field() => null,
        },
    ];

    test('is what an arrow body or a lone return returns', () {
      final returns = returnsOf('''
abstract class C {
  C();
  factory C.a() => b;
  factory C.c() { return d; }
  int e() => f;
  int g() { return h; }
  int i() { j; return k; }
  int l() {}
  int m();
}
''');
      expect(returns.map((e) => (e as Reference?)?.name), [
        null,
        'b',
        'd',
        'f',
        'h',
        null,
        null,
        null,
      ]);
    });
  });

  group(TypeAnnotation, () {
    List<TypeAnnotation> types(String source) => _parse(source).typeAnnotations;

    test('are every type annotation in source order', () {
      expect(types('Map<String, List<int>> m = {};').map((t) => t.name), [
        'Map',
        'String',
        'List',
        'int',
      ]);
    });

    test('have their type arguments', () {
      final map = types('Map<String, dynamic> m = {};').first;
      expect(map.typeArguments.map((t) => t.name), ['String', 'dynamic']);
      expect(map.typeArguments.first.typeArguments, isEmpty);
    });

    test('have a prefix', () {
      final map = types('core.Map m = {};').single;
      expect((map.prefix, map.name), ('core', 'Map'));
      expect(map.typeArguments, isEmpty);
    });

    test('have no name, prefix or arguments for function and record types', () {
      final annotations = types('void Function() f = g; (int, int) r = x;');
      final unnamed = [annotations[0], annotations[2]];
      expect(unnamed.map((t) => t.name), [null, null]);
      expect(unnamed.map((t) => t.prefix), [null, null]);
      expect(unnamed.map((t) => t.typeArguments), [isEmpty, isEmpty]);
    });

    test('know the cast they are the type of', () {
      final file = _parse('f() => a as Map<String, dynamic>;');
      final cast = file.expressions.whereType<Cast>().single;
      expect(file.typeAnnotations.first.cast, same(cast));
      expect(cast.type, same(file.typeAnnotations.first));
      expect(file.typeAnnotations[1].cast, isNull);
    });

    test('are at their start', () {
      const source = 'f() => a as Map<String, dynamic>;';
      final type = _parse(source).typeAnnotations.first;
      expect(type.offset, source.indexOf('Map'));
      expect(type.symbol, 'f');
    });
  });
}
