import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Reports `fromJson` and `toJson` members that json_serializable doesn't
/// generate.
///
/// A `fromJson` factory constructor or `toJson` method passes when its
/// class is annotated with `@JsonSerializable`. A `fromJson` method is
/// always reported, since json_serializable expects a constructor.
final class const GeneratedJsonRule() extends Rule {
  /// Creates the rule.
  this;

  @override
  String get id => 'generated-json';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  List<Finding> check(ParsedFile file) => [
    for (final declaration in file.unit.declarations)
      if (declaration case ClassDeclaration(
        :final namePart,
        :final metadata,
        :final body,
      ))
        for (final member in body.members)
          ?_check(namePart.typeName.lexeme, _isAnnotated(metadata), member),
  ];

  Finding? _check(String className, bool annotated, ClassMember member) {
    switch (member) {
      case MethodDeclaration(:final name, isGetter: false, isSetter: false)
          when name.lexeme == 'fromJson':
        return Finding(
          offset: name.offset,
          symbol: '$className.fromJson',
          message:
              '`$className.fromJson` is a method. Make it a factory '
              'constructor, `factory $className.fromJson(Map<String, dynamic> '
              'json) => _\$${className}FromJson(json);`.',
        );
      case ConstructorDeclaration(name: final name?)
          when name.lexeme == 'fromJson' && !annotated:
        return _unannotated(className, name);
      case MethodDeclaration(:final name, isGetter: false, isSetter: false)
          when name.lexeme == 'toJson' && !annotated:
        return _unannotated(className, name);
      default:
        return null;
    }
  }

  bool _isAnnotated(List<Annotation> metadata) => metadata.any(
    (annotation) => switch (annotation.name) {
      SimpleIdentifier(name: 'JsonSerializable') => true,
      PrefixedIdentifier(
        identifier: SimpleIdentifier(name: 'JsonSerializable'),
      ) =>
        true,
      _ => false,
    },
  );

  Finding _unannotated(String className, Token name) {
    final generated = name.lexeme == 'fromJson'
        ? '_\$${className}FromJson'
        : '_\$${className}ToJson';
    return Finding(
      offset: name.offset,
      symbol: '$className.${name.lexeme}',
      message:
          '`$className.${name.lexeme}` is written by hand. Annotate '
          '`$className` with `@JsonSerializable()` and delegate to '
          '`$generated`. Use a `JsonConverter` for fields that need custom '
          'parsing.',
    );
  }
}
