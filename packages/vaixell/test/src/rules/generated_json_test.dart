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
