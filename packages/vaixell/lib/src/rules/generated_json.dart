import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Reports `fromJson` and `toJson` members that json_serializable doesn't
/// generate.
///
/// A `fromJson` factory constructor or `toJson` method passes when its
/// class is annotated with `@JsonSerializable` and its body only returns
/// `_$<Class>FromJson(json, …)` or `_$<Class>ToJson(this, …)`. A `fromJson`
/// method is always reported, since json_serializable expects a constructor.
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
      case ConstructorDeclaration(name: final name?, :final body)
          when name.lexeme == 'fromJson':
        final input = member.parameters.parameters.firstOrNull?.name?.lexeme;
        return _member(className, annotated, name, body, input ?? 'json');
      case MethodDeclaration(
            :final name,
            :final body,
            isGetter: false,
            isSetter: false,
          )
          when name.lexeme == 'toJson':
        return _member(className, annotated, name, body, 'this');
      default:
        return null;
    }
  }

  /// Returns a finding for the `fromJson` or `toJson` member [name] with
  /// [body], unless [className] is [annotated] and [body] returns a call to
  /// the generated function with [input] as its first argument.
  Finding? _member(
    String className,
    bool annotated,
    Token name,
    FunctionBody body,
    String input,
  ) {
    final suffix = name.lexeme == 'fromJson' ? 'FromJson' : 'ToJson';
    final generated = '_\$$className$suffix';
    if (!annotated) return _unannotated(className, name, generated);
    final call = switch (body) {
      ExpressionFunctionBody(:final expression) => expression,
      BlockFunctionBody(
        block: Block(statements: [ReturnStatement(:final expression?)]),
      ) =>
        expression,
      _ => null,
    };
    if (call
        case MethodInvocation(
          target: null,
          :final methodName,
          argumentList: ArgumentList(arguments: [final Expression first, ...]),
        )
        when methodName.name == generated && _isInput(first, input)) {
      return null;
    }
    return Finding(
      offset: name.offset,
      symbol: '$className.${name.lexeme}',
      message:
          '`$className.${name.lexeme}` is written by hand. Return '
          '`$generated($input)` instead. Use a `JsonConverter` for fields '
          'that need custom parsing.',
    );
  }

  bool _isInput(Expression argument, String input) => switch (argument) {
    ThisExpression() => input == 'this',
    SimpleIdentifier(:final name) => name == input,
    _ => false,
  };

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

  Finding _unannotated(String className, Token name, String generated) =>
      Finding(
        offset: name.offset,
        symbol: '$className.${name.lexeme}',
        message:
            '`$className.${name.lexeme}` is written by hand. Annotate '
            '`$className` with `@JsonSerializable()` and delegate to '
            '`$generated`. Use a `JsonConverter` for fields that need custom '
            'parsing.',
      );
}
