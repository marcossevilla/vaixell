import 'package:test/test.dart';
import 'package:vaixell/src/rules/generated_json.dart';
import 'package:vaixell/vaixell.dart';

import '../../helpers/parse.dart';

void main() {
  group(GeneratedJsonRule, () {
    const rule = GeneratedJsonRule();

    List<String?> symbols(String source, {String path = 'lib/a.dart'}) =>
        rule.check(parse(source, path: path)).map((f) => f.symbol).toList();

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
        final findings = rule.check(parse(source));
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
        final findings = rule.check(parse(source));
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

      test('explains how to delegate', () {
        final findings = rule.check(
          parse('''
@JsonSerializable()
class User {
  factory User.fromJson(Map<String, dynamic> json) => User();
  Map<String, dynamic> toJson() => {};
}
'''),
        );
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
      final findings = rule.check(
        parse('''
class User {
  factory User.fromJson(Map<String, dynamic> json) => User();
  Map<String, dynamic> toJson() => {};
}
'''),
      );
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

    group('fromJson methods', () {
      test('are flagged on unannotated classes', () {
        final findings = rule.check(
          parse('''
class User {
  static User fromJson(Map<String, dynamic> json) => User();
}
'''),
        );
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

      test('are flagged on annotated classes with a delegating body', () {
        expect(
          symbols(r'''
@JsonSerializable()
class User {
  static User fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  User fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
'''),
          equals(['User.fromJson', 'User.fromJson']),
        );
      });
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
