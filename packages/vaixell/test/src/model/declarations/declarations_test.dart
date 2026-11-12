import 'package:test/test.dart';
import 'package:vaixell/src/model/model.dart';

List<Declaration> _declarations(String source) =>
    DartFile.parse(path: 'lib/a.dart', content: source).declarations;

T _single<T extends Declaration>(String source) =>
    _declarations(source).single as T;

void main() {
  group(Declaration, () {
    const topLevel = '''
class C {}
mixin M {}
enum E { a }
extension X on int {}
extension on int {}
extension type T(int v) {}
void f() {}
int get g => 1;
set s(int v) {}
const a = 1, b = 2;
typedef J = int;
''';

    test('lists top-level declarations in source order', () {
      expect(_declarations(topLevel), [
        isA<ClassDeclaration>(),
        isA<MixinDeclaration>(),
        isA<EnumDeclaration>(),
        isA<ExtensionDeclaration>(),
        isA<ExtensionDeclaration>(),
        isA<ExtensionTypeDeclaration>(),
        isA<TopLevelFunction>(),
        isA<TopLevelFunction>(),
        isA<TopLevelFunction>(),
        isA<TopLevelVariable>(),
        isA<TopLevelVariable>(),
      ]);
    });

    test('have symbols, with `<unnamed>` and `=` for setters', () {
      expect(_declarations(topLevel).map((d) => d.symbol), [
        'C',
        'M',
        'E',
        'X',
        '<unnamed>',
        'T',
        'f',
        'g',
        's=',
        'a',
        'b',
      ]);
    });

    test('give an extension its extended type, as in the file', () {
      final file = DartFile.parse(
        path: 'lib/a.dart',
        content: 'extension X on core.Map<String, int> {}\n',
      );
      final extension = file.declarations.single as ExtensionDeclaration;
      expect(extension.extendedType?.name, equals('Map'));
      expect(extension.extendedType?.prefix, equals('core'));
      expect(extension.extendedType, same(file.typeAnnotations.first));
    });

    test('are at their name, or the keyword when unnamed', () {
      const source = '''
class C {}
mixin M {}
enum E { a }
extension X on int {}
extension on int {}
extension type T(int v) {}
void f() {}
''';
      final declarations = _declarations(source);
      expect(declarations.map((d) => d.offset), [
        source.indexOf('C {'),
        source.indexOf('M {'),
        source.indexOf('E {'),
        source.indexOf('X on'),
        source.indexOf('extension on'),
        source.indexOf('T('),
        source.indexOf('f()'),
      ]);
    });

    group('keep the same objects on every read', () {
      final file = DartFile.parse(
        path: 'lib/a.dart',
        content: '@A(1) class C { int f = 0; C(); void m(int p) {} }',
      );
      final type = file.declarations.single as TypeDeclaration;

      test('for declarations and members', () {
        expect(file.declarations.single, same(file.declarations.single));
        expect(type.members[2], same(type.methods.single));
      });

      for (final (name, list) in <(String, List<Object> Function())>[
        ('members', () => type.members),
        ('methods', () => type.methods),
        ('constructors', () => type.constructors),
        ('fields', () => type.fields),
        ('annotations', () => type.annotations),
        ('annotation arguments', () => type.annotations.single.arguments),
        ('method parameters', () => type.methods.single.parameters),
        ('constructor parameters', () => type.constructors.single.parameters),
      ]) {
        test('in an unmodifiable list of $name', () {
          expect(list(), same(list()));
          expect(() => list().clear(), throwsUnsupportedError);
        });
      }
    });

    group(TypeDeclaration, () {
      test('have names, except unnamed extensions', () {
        final names = [
          for (final declaration in _declarations('''
class C {}
mixin M {}
enum E { a }
extension X on int {}
extension on int {}
extension type T(int v) {}
'''))
            (declaration as TypeDeclaration).name,
        ];
        expect(names, ['C', 'M', 'E', 'X', null, 'T']);
      });

      test('list members in source order, one field per name', () {
        final type = _single<ClassDeclaration>('''
class C {
  int a = 1, b = 2;
  C();
  void m() {}
  static int c = 3;
  C.named();
}
''');
        expect(type.members.map((m) => m.symbol), [
          'C.a',
          'C.b',
          'C.new',
          'C.m',
          'C.c',
          'C.named',
        ]);
        expect(type.fields.map((f) => f.name), ['a', 'b', 'c']);
        expect(type.methods.map((m) => m.name), ['m']);
        expect(type.constructors.map((c) => c.name), [null, 'named']);
      });

      test('have members in every kind of declaration', () {
        final symbols = [
          for (final declaration in _declarations('''
mixin M { void m() {} }
enum E { a; void m() {} }
extension on int { void m() {} }
extension type T(int v) { void m() {} }
'''))
            for (final member in (declaration as TypeDeclaration).members)
              member.symbol,
        ];
        expect(symbols, ['M.m', 'E.m', '<unnamed>.m', 'T.new', 'T.m']);
      });

      test('read their annotations', () {
        final type = _single<ClassDeclaration>('''
@a
@json.JsonSerializable(createToJson: false, 1)
@A.named()
class C {}
''');
        expect(type.annotations.map((a) => (a.prefix, a.name)), [
          (null, 'a'),
          ('json', 'JsonSerializable'),
          ('A', 'named'),
        ]);
        expect(type.annotations.first.arguments, isEmpty);
        expect(type.annotations[1].arguments.map((a) => a.name), [
          'createToJson',
          null,
        ]);
      });

      test('find an annotation by name, whatever its prefix', () {
        final type = _single<ClassDeclaration>('''
@a
@json.JsonSerializable()
@JsonSerializable(createToJson: false)
class C {}
''');
        expect(
          type.annotationNamed('JsonSerializable'),
          same(type.annotations[1]),
        );
        expect(type.annotationNamed('a'), same(type.annotations.first));
        expect(type.annotationNamed('json'), isNull);
      });
    });

    group(TopLevelFunction, () {
      test('have a name and a kind', () {
        final functions = _declarations(
          'void f() {}\nint get g => 1;\nset s(int v) {}\n',
        ).cast<TopLevelFunction>();
        expect(functions.map((f) => (f.name, f.kind)), [
          ('f', FunctionKind.function),
          ('g', FunctionKind.getter),
          ('s', FunctionKind.setter),
        ]);
      });
    });

    group(TopLevelVariable, () {
      test('have one per name, at the name, and know if they are const', () {
        const source = 'const a = 1, b = 2;\nfinal c = 3;\n';
        final variables = _declarations(source).cast<TopLevelVariable>();
        expect(variables.map((v) => (v.name, v.isConst)), [
          ('a', true),
          ('b', true),
          ('c', false),
        ]);
        expect(variables.map((v) => v.offset), [
          source.indexOf('a ='),
          source.indexOf('b ='),
          source.indexOf('c ='),
        ]);
      });
    });
  });

  group(FunctionKind, () {
    test('names member kinds', () {
      expect(FunctionKind.values.map((k) => k.asMember), [
        'method',
        'getter',
        'setter',
        'operator',
      ]);
    });
  });

  group(Member, () {
    test('are function members, except fields, and have a name', () {
      final members = _single<ClassDeclaration>('''
class C {
  C();
  C.named();
  void m() {}
  int f = 1;
}
''').members;
      expect(members.map((m) => m is FunctionMember), [
        true,
        true,
        true,
        false,
      ]);
      expect(members.map((m) => m.name), [null, 'named', 'm', 'f']);
    });

    group(Method, () {
      const source = '''
abstract class C {
  void m(int a, [int b = 0]) {}
  static int get g => 1;
  set s(int v) {}
  bool operator ==(Object other) => true;
  void abstract();
  external void ext();
}
''';
      final methods = _single<ClassDeclaration>(source).methods;

      test('have a name, a kind and a symbol, at the name', () {
        expect(methods.map((m) => (m.name, m.kind, m.symbol)), [
          ('m', FunctionKind.function, 'C.m'),
          ('g', FunctionKind.getter, 'C.g'),
          ('s', FunctionKind.setter, 'C.s='),
          ('==', FunctionKind.operator, 'C.=='),
          ('abstract', FunctionKind.function, 'C.abstract'),
          ('ext', FunctionKind.function, 'C.ext'),
        ]);
        expect(methods.first.offset, source.indexOf('m('));
      });

      test('know if they are static', () {
        expect(methods.where((m) => m.isStatic).map((m) => m.name), ['g']);
      });

      test('know if they are abstract', () {
        expect(methods.where((m) => m.isAbstract).map((m) => m.name), [
          'abstract',
          'ext',
        ]);
      });

      test('know if they are external', () {
        expect(methods.where((m) => m.isExternal).map((m) => m.name), ['ext']);
      });

      test('have parameters, none for a getter', () {
        expect(methods.first.parameters.map((p) => p.name), ['a', 'b']);
        expect(methods[1].parameters, isEmpty);
      });
    });

    group(Constructor, () {
      const source = '''
class C {
  C();
  C.named();
  factory C.f() => C();
  external C.e();
  new n();
}
class D {
  new();
}
class E {
  factory() => E();
}
''';
      final declarations = _declarations(source).cast<ClassDeclaration>();
      final constructors = declarations.first.constructors;

      test('have a name and a symbol', () {
        expect(constructors.map((c) => (c.name, c.symbol)), [
          (null, 'C.new'),
          ('named', 'C.named'),
          ('f', 'C.f'),
          ('e', 'C.e'),
          ('n', 'C.n'),
        ]);
      });

      test('are at the name, or the type name or keyword when unnamed', () {
        expect(constructors.first.offset, source.indexOf('C();'));
        expect(constructors[1].offset, source.indexOf('named'));
        expect(
          declarations[1].constructors.single.offset,
          source.indexOf('new();'),
        );
        expect(
          declarations[2].constructors.single.offset,
          source.indexOf('factory()'),
        );
      });

      test('know if they are factories or external', () {
        expect(constructors.map((c) => c.isFactory), [
          false,
          false,
          true,
          false,
          false,
        ]);
        expect(constructors.map((c) => c.isExternal), [
          false,
          false,
          false,
          true,
          false,
        ]);
      });

      test('have parameters', () {
        final constructor = _single<ClassDeclaration>(
          'class C { C(this.a, {required int b}); }',
        ).constructors.single;
        expect(constructor.parameters.map((p) => p.name), ['a', 'b']);
      });

      group('primary', () {
        const source = '''
class const C.named(final int a, {int? b}) {
  int f = 0;
  this : assert(a > 0);
}
enum const E(final int x) { a(1) }
class D(int a);
''';
        final declarations = _declarations(source).cast<TypeDeclaration>();

        test('come first in members, once with their body', () {
          expect(declarations.first.members.map((m) => m.symbol), [
            'C.named',
            'C.f',
          ]);
          expect(declarations.map((d) => d.constructors.single.symbol), [
            'C.named',
            'E.new',
            'D.new',
          ]);
        });

        test('are at the name, or the type name when unnamed', () {
          expect(declarations.map((d) => d.constructors.single.offset), [
            source.indexOf('named'),
            source.indexOf('E('),
            source.indexOf('D('),
          ]);
        });

        test('have parameters and nothing else', () {
          final constructor = declarations.first.constructors.single;
          expect(constructor.name, 'named');
          expect(constructor.parameters.map((p) => p.name), ['a', 'b']);
          expect(constructor.isFactory, isFalse);
          expect(constructor.isExternal, isFalse);
          expect(constructor.returnExpression, isNull);
        });
      });
    });

    group(Field, () {
      test('have one per name, at the name, and know if they are static', () {
        const source = 'class C { int a = 1, b = 2; static int c = 3; }';
        final fields = _single<ClassDeclaration>(source).fields;
        expect(fields.map((f) => (f.symbol, f.isStatic)), [
          ('C.a', false),
          ('C.b', false),
          ('C.c', true),
        ]);
        expect(fields[1].offset, source.indexOf('b ='));
      });
    });
  });

  group(Parameter, () {
    test('know if they are positional, named or functions', () {
      final parameters = _single<ClassDeclaration>('''
class C {
  void m(int a, [int b = 0]) {}
  void n({int? c, T Function<T>(Object?)? d, T e<T>()?}) {}
}
''').methods.expand((m) => m.parameters).toList();
      expect(parameters.map((p) => p.name), ['a', 'b', 'c', 'd', 'e']);
      expect(parameters.map((p) => p.isPositional), [
        true,
        true,
        false,
        false,
        false,
      ]);
      expect(parameters.map((p) => p.isNamed), [
        false,
        false,
        true,
        true,
        true,
      ]);
      expect(parameters.map((p) => p.isFunction), [
        false,
        false,
        false,
        true,
        true,
      ]);
    });
  });

  group(Argument, () {
    test('read bool, number, string and null literals', () {
      final arguments = _single<ClassDeclaration>(r'''
@A(true, 1, 2.5, 's', null, x, 'a$b', f: false)
class C {}
''').annotations.single.arguments;
      expect(arguments.map((a) => a.isLiteral), [
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        true,
      ]);
      expect(arguments.map((a) => a.literal), [
        true,
        1,
        2.5,
        's',
        null,
        null,
        null,
        false,
      ]);
      expect(arguments.last.name, 'f');
    });

    test('are found by name in an annotation', () {
      final annotation = _single<ClassDeclaration>('''
@A(1, a: true, b: false)
class C {}
''').annotations.single;
      expect(annotation.argumentNamed('b')?.literal, false);
      expect(annotation.argumentNamed('a'), same(annotation.arguments[1]));
      expect(annotation.argumentNamed('c'), isNull);
    });
  });
}
