import 'package:test/test.dart';
import 'package:vaixell/src/rules/generated_json.dart';
import 'package:vaixell/testing.dart';
import 'package:vaixell/vaixell.dart';

const _tester = RuleTester();

void main() {
  group(GeneratedJsonRule, () {
    const rule = GeneratedJsonRule();

    List<String?> symbols(String source, {String path = 'lib/a.dart'}) =>
        _tester
            .checkSource(rule, source, path: path)
            .map((f) => f.symbol)
            .toList();

    test('has the expected id and defaults to warning', () {
      expect(rule.id, equals('generated-json'));
      expect(rule.defaultSeverity, equals(Severity.warning));
    });

    group('on a class without @JsonSerializable', () {
      test('flags fromJson constructors and toJson methods', () {
        const source = '''
class User {
  factory User.fromJson(Map<String, dynamic> json) => User();
  Map<String, dynamic> toJson() => {};
}
''';
        final findings = _tester.checkSource(rule, source);
        expect(
          findings.map((f) => f.symbol),
          equals(['User.fromJson', 'User.toJson']),
        );
        expect(
          findings.map((f) => f.offset),
          equals([source.indexOf('fromJson'), source.indexOf('toJson')]),
        );
      });

      test('flags the new factory fromJson syntax', () {
        const source = '''
class User {
  factory fromJson(Map<String, Object?> json) => User();
}
''';
        final findings = _tester.checkSource(rule, source);
        expect(findings.map((f) => f.symbol), equals(['User.fromJson']));
        expect(findings.single.offset, equals(source.indexOf('fromJson')));
      });

      test('flags files under a models directory', () {
        expect(
          symbols(
            'class User { Map<String, dynamic> toJson() => {}; }\n',
            path: 'lib/models/user.dart',
          ),
          equals(['User.toJson']),
        );
      });

      test('ignores toJson getters and setters and other members', () {
        expect(
          symbols('''
class User {
  User();
  factory User.create() => User();
  Map<String, dynamic> get toJson => {};
  set toJson(Map<String, dynamic> value) {}
  void encode() {}
}
'''),
          isEmpty,
        );
      });

      test('flags generative fromJson constructors', () {
        expect(
          symbols('''
class User {
  User.fromJson(Map<String, dynamic> json) : name = json['name'] as String;
  final String name;
}
'''),
          equals(['User.fromJson']),
        );
      });

      test('flags primary fromJson constructors', () {
        const source = '''
@JsonSerializable()
class const User.fromJson(final Map<String, dynamic> json);
''';
        final findings = _tester.checkSource(rule, source);
        expect(findings.map((f) => f.symbol), equals(['User.fromJson']));
        expect(findings.single.offset, equals(source.indexOf('fromJson')));
      });

      test('ignores external fromJson constructors', () {
        expect(
          symbols('''
class User {
  external factory User.fromJson(Map<String, dynamic> json);
}
'''),
          isEmpty,
        );
      });

      test('flags polymorphic fromJson factories on sealed classes', () {
        expect(
          symbols('''
sealed class Shape {
  factory Shape.fromJson(Map<String, dynamic> json) => switch (json['type']) {
    'circle' => Circle.fromJson(json),
    _ => Square.fromJson(json),
  };
}
'''),
          equals(['Shape.fromJson']),
        );
      });

      test('ignores abstract members', () {
        expect(
          symbols('''
abstract class Block {
  Map<String, dynamic> toJson();
  Block fromJson(Map<String, dynamic> json);
}
'''),
          isEmpty,
        );
      });

      test('explains that delegating members need the annotation', () {
        final findings = _tester.checkSource(rule, r'''
@freezed
abstract class User with _$User {
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
''');
        expect(
          findings.first.message,
          equals(
            r'`User.fromJson` delegates to `_$UserFromJson`, but `User` '
            "isn't annotated with `@JsonSerializable()`. Annotate it "
            "directly, since vaixell doesn't recognize aliases such as "
            '`@jsonSerializable`. Set `generated-json: off` if you use '
            'another generator, such as freezed.',
          ),
        );
        expect(
          findings.last.message,
          startsWith(r'`User.toJson` delegates to `_$UserToJson`, but'),
        );
      });
    });

    group('on a class with @JsonSerializable', () {
      test('accepts members that delegate to generated code', () {
        expect(
          symbols(r'''
@JsonSerializable()
class A {
  factory A.fromJson(Map<String, dynamic> json) => _$AFromJson(json);
  Map<String, dynamic> toJson() => _$AToJson(this);
}
@JsonSerializable
class B {
  factory fromJson(Map<String, dynamic> data) {
    return _$BFromJson(data);
  }
  Map<String, dynamic> toJson() {
    return _$BToJson(this);
  }
}
@js.JsonSerializable(genericArgumentFactories: true)
class C<T> {
  factory C.fromJson(Map<String, dynamic> json, T Function(Object?) f) =>
      _$CFromJson<T>(json, f);
  Map<String, dynamic> toJson(Object? Function(T) f) => _$CToJson<T>(this, f);
}
'''),
          isEmpty,
        );
      });

      test('flags members that do not delegate', () {
        expect(
          symbols(r'''
@JsonSerializable()
class A {
  factory A.fromJson(Map<String, dynamic> json) => _$BFromJson(json);
  Map<String, dynamic> toJson() => _$BToJson(this);
}
@JsonSerializable()
class B {
  factory B.fromJson(Map<String, dynamic> json) => _$BFromJson(other);
  Map<String, dynamic> toJson() => _$BToJson(other);
}
@JsonSerializable()
class C {
  factory C.fromJson(Map<String, dynamic> json) {
    print(json);
    return _$CFromJson(json);
  }
  Map<String, dynamic> toJson() => {'a': 1};
}
@JsonSerializable()
class D {
  factory D.fromJson(Map<String, dynamic> json) = D.create;
  Map<String, dynamic> toJson() => x._$DToJson(this);
}
@JsonSerializable()
class E {
  factory E.fromJson() => _$EFromJson();
  Map<String, dynamic> toJson() => _$EToJson();
}
@JsonSerializable(createFactory: false, createToJson: false)
class F {
  factory F.fromJson(Map<String, dynamic> json) => F(json['a']);
  Map<String, dynamic> toJson() {
    return {'a': a};
  }
}
@freezed
class G {
  factory G.fromJson(Map<String, dynamic> json) => _$GFromJson(json);
}
'''),
          equals([
            for (final c in ['A', 'B', 'C', 'D', 'E', 'F']) ...[
              '$c.fromJson',
              '$c.toJson',
            ],
            'G.fromJson',
          ]),
        );
      });

      test('accepts a null-checked or cast input', () {
        expect(
          symbols(r'''
@JsonSerializable()
class A {
  factory A.fromJson(Object? json) =>
      _$AFromJson(json! as Map<String, dynamic>);
}
@JsonSerializable()
class B {
  factory B.fromJson(Object? json) => _$BFromJson(json as Map<String, dynamic>);
}
'''),
          isEmpty,
        );
      });

      test('drops leading underscores from private class names', () {
        expect(
          symbols(r'''
@JsonSerializable()
class _User {
  factory _User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
'''),
          isEmpty,
        );
        final findings = _tester.checkSource(rule, '''
@JsonSerializable()
class __User {
  factory __User.fromJson(Map<String, dynamic> json) => __User();
}
''');
        expect(findings.map((f) => f.symbol), equals(['__User.fromJson']));
        expect(
          findings.single.message,
          equals(
            '`__User.fromJson` is written by hand. Return '
            r'`_$UserFromJson(json)` instead. Use a `JsonConverter` for '
            'fields that need custom parsing.',
          ),
        );
      });

      test('explains how to re-enable a disabled generated function', () {
        final findings = _tester.checkSource(rule, '''
@JsonSerializable(createFactory: false, createToJson: false)
class User {
  factory User.fromJson(Map<String, dynamic> json) => User();
  Map<String, dynamic> toJson() => {};
}
''');
        expect(
          findings.first.message,
          equals(
            '`User.fromJson` is written by hand. Remove '
            '`createFactory: false` from `@JsonSerializable` and return '
            r'`_$UserFromJson(json)` instead. Use a `JsonConverter` for '
            'fields that need custom parsing.',
          ),
        );
        expect(
          findings.last.message,
          equals(
            '`User.toJson` is written by hand. Remove `createToJson: false` '
            r'from `@JsonSerializable` and return `_$UserToJson(this)` '
            'instead. Use a `JsonConverter` for fields that need custom '
            'parsing.',
          ),
        );
      });

      test('explains how to delegate', () {
        final findings = _tester.checkSource(rule, '''
@JsonSerializable()
class User {
  factory User.fromJson(Map<String, dynamic> json) => User();
  Map<String, dynamic> toJson() => {};
}
''');
        expect(
          findings.first.message,
          equals(
            '`User.fromJson` is written by hand. Return '
            r'`_$UserFromJson(json)` instead. Use a `JsonConverter` for '
            'fields that need custom parsing.',
          ),
        );
        expect(
          findings.last.message,
          equals(
            '`User.toJson` is written by hand. Return '
            r'`_$UserToJson(this)` instead. Use a `JsonConverter` for '
            'fields that need custom parsing.',
          ),
        );
      });
    });

    test('explains how to annotate an unannotated class', () {
      final findings = _tester.checkSource(rule, '''
class User {
  factory User.fromJson(Map<String, dynamic> json) => User();
  Map<String, dynamic> toJson() => {};
}
''');
      expect(
        findings.first.message,
        equals(
          '`User.fromJson` is written by hand. Annotate `User` with '
          r'`@JsonSerializable()` and delegate to `_$UserFromJson`. Use a '
          '`JsonConverter` for fields that need custom parsing.',
        ),
      );
      expect(
        findings.last.message,
        equals(
          '`User.toJson` is written by hand. Annotate `User` with '
          r'`@JsonSerializable()` and delegate to `_$UserToJson`. Use a '
          '`JsonConverter` for fields that need custom parsing.',
        ),
      );
    });

    group('static fromJson methods', () {
      test('are flagged on unannotated classes', () {
        final findings = _tester.checkSource(rule, '''
class User {
  static User fromJson(Map<String, dynamic> json) => User();
}
''');
        expect(findings.map((f) => f.symbol), equals(['User.fromJson']));
        expect(
          findings.single.message,
          equals(
            '`User.fromJson` is a method. Make it a factory constructor, '
            '`factory User.fromJson(Map<String, dynamic> json) => '
            r'_$UserFromJson(json);`.',
          ),
        );
      });

      test('name the generated function without leading underscores', () {
        expect(
          _tester
              .checkSource(rule, '''
class _User {
  static _User fromJson(Map<String, dynamic> json) => _User();
}
''')
              .single
              .message,
          endsWith(r'=> _$UserFromJson(json);`.'),
        );
      });

      test('are flagged on annotated classes with a delegating body', () {
        expect(
          symbols(r'''
@JsonSerializable()
class User {
  static User fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
'''),
          equals(['User.fromJson']),
        );
      });
    });

    group('helpers that convert another value', () {
      test('ignore HydratedBloc overrides', () {
        expect(
          symbols('''
class ThemeModeBloc extends HydratedBloc<ThemeModeEvent, ThemeMode> {
  @override
  ThemeMode fromJson(Map<String, dynamic> json) =>
      ThemeMode.values[json['theme_mode'] as int];

  @override
  Map<String, int> toJson(ThemeMode state) => {'theme_mode': state.index};
}
'''),
          isEmpty,
        );
      });

      test('ignore JsonConverter implementations', () {
        expect(
          symbols('''
class ActionConverter implements JsonConverter<Action?, Object?> {
  const ActionConverter();

  @override
  Action? fromJson(Object? json) => Action.fromJson(json);

  @override
  Object? toJson(Action? action) => action?.toJson();
}
'''),
          isEmpty,
        );
      });

      test('ignore toJson with an untyped or optional value parameter', () {
        expect(
          symbols('''
class A {
  Object? toJson(value) => value;
}
class B {
  Object? toJson([Object? value]) => value;
}
'''),
          isEmpty,
        );
      });

      test('do not include toJson with only function parameters', () {
        expect(
          symbols('''
class A<T> {
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) => {};
}
class B<T> {
  Map<String, dynamic> toJson(Object? toJsonT(T value)) => {};
}
class C<T> {
  Map<String, dynamic> toJson({Object? Function(T)? toJsonT}) => {};
}
class D<T> {
  Map<String, dynamic> toJson(
    Object? Function(T) toJsonT, {
    bool pretty = false,
  }) => {};
}
'''),
          equals(['A.toJson', 'B.toJson', 'C.toJson', 'D.toJson']),
        );
      });
    });

    test('flags fromJson and toJson in enums, even when they delegate', () {
      final findings = _tester.checkSource(rule, r'''
@JsonEnum()
enum Status {
  active;
  factory Status.fromJson(String json) => _$StatusFromJson(json);
  static Status fromJson(String json) => active;
  String toJson() => _$StatusToJson(this);
  String get toJson => name;
}
''');
      expect(
        findings.map((f) => f.symbol),
        equals(['Status.fromJson', 'Status.fromJson', 'Status.toJson']),
      );
      expect(
        findings.first.message,
        equals(
          '`Status.fromJson` is written by hand. Annotate `Status` with '
          '`@JsonEnum()` and its values with `@JsonValue` instead.',
        ),
      );
    });

    test('ignores value converters in enums', () {
      expect(
        symbols('''
enum Color {
  red;
  Color fromJson(String json) => Color.values.byName(json);
  String toJson(Color object) => object.name;
}
'''),
        isEmpty,
      );
    });

    test('ignores mixins, extensions and extension types', () {
      expect(
        symbols('''
mixin M {
  Map<String, dynamic> toJson() => {};
}
extension X on int {
  Map<String, dynamic> toJson() => {};
}
extension on int {
  Map<String, dynamic> toJson() => {};
}
extension type Id(int v) {
  factory Id.fromJson(Object? json) => Id(json! as int);
  int toJson() => v;
}
'''),
        isEmpty,
      );
    });

    test('ignores top-level functions and type aliases', () {
      expect(
        symbols('''
Map<String, dynamic> toJson() => {};
mixin M {}
class A = Object with M;
typedef F = void Function();
'''),
        isEmpty,
      );
    });
  });
}
