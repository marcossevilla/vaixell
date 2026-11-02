import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Reports `fromJson` and `toJson` members that json_serializable doesn't
/// generate.
///
/// A `fromJson` constructor or `toJson` method passes when its class is
/// annotated with `@JsonSerializable` and its body only returns
/// `_$<Class>FromJson(json, …)` or `_$<Class>ToJson(this, …)`, where
/// `<Class>` drops any leading underscores. A static `fromJson` method is
/// always reported, since json_serializable expects a constructor.
///
/// Abstract and external members aren't reported. Neither are instance
/// `fromJson` methods or `toJson` methods whose first positional parameter
/// is a value, such as HydratedBloc overrides and `JsonConverter`
/// implementations, since they convert another value rather than the class
/// itself.
///
/// The same members are reported in enums, whatever their body, since
/// `@JsonEnum` and `@JsonValue` replace them. Mixins, extensions and
/// extension types aren't checked, since they can't be annotated with
/// `@JsonSerializable`.
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
      ...switch (declaration) {
        ClassDeclaration(:final namePart, :final metadata, :final body) => [
          for (final member in body.members)
            if (_jsonName(member) case final name?)
              ?_check(
                namePart.typeName.lexeme,
                _annotation(metadata),
                member,
                name,
              ),
        ],
        EnumDeclaration(:final namePart, :final body) => [
          for (final member in body.members)
            if (_jsonName(member) case final name?)
              _enum(namePart.typeName.lexeme, name),
        ],
        _ => const <Finding>[],
      },
  ];

  /// Returns the name token of [member] if it's a `fromJson` constructor, a
  /// static `fromJson` method or a `toJson` method for the type itself.
  Token? _jsonName(ClassMember member) => switch (member) {
    ConstructorDeclaration(name: final name?, externalKeyword: null)
        when name.lexeme == 'fromJson' =>
      name,
    MethodDeclaration(body: EmptyFunctionBody()) => null,
    MethodDeclaration(
      :final name,
      isStatic: true,
      isGetter: false,
      isSetter: false,
    )
        when name.lexeme == 'fromJson' =>
      name,
    MethodDeclaration(
      :final name,
      parameters: final parameters?,
      isGetter: false,
      isSetter: false,
    )
        when name.lexeme == 'toJson' && !_convertsValue(parameters) =>
      name,
    _ => null,
  };

  /// Whether the first positional parameter in [parameters] is a value
  /// rather than a function. A `toJson` that takes a value to convert, as
  /// in HydratedBloc or a `JsonConverter`, isn't a model's `toJson`, which
  /// only takes functions with `genericArgumentFactories`.
  bool _convertsValue(FormalParameterList parameters) =>
      switch (parameters.parameters.where((p) => p.isPositional).firstOrNull) {
        final parameter? =>
          parameter.functionTypedSuffix == null &&
              parameter.type is! GenericFunctionType,
        null => false,
      };

  Finding _enum(String enumName, Token name) => Finding(
    offset: name.offset,
    symbol: '$enumName.${name.lexeme}',
    message:
        '`$enumName.${name.lexeme}` is written by hand. Annotate `$enumName` '
        'with `@JsonEnum()` and its values with `@JsonValue` instead.',
  );

  Finding? _check(
    String className,
    Annotation? annotation,
    ClassMember member,
    Token name,
  ) => switch (member) {
    MethodDeclaration(isStatic: true) when name.lexeme == 'fromJson' => Finding(
      offset: name.offset,
      symbol: '$className.fromJson',
      message:
          '`$className.fromJson` is a method. Make it a factory '
          'constructor, `factory $className.fromJson(Map<String, dynamic> '
          'json) => ${_generated(className, name)}(json);`.',
    ),
    ConstructorDeclaration(:final body, :final parameters) => _member(
      className,
      annotation,
      name,
      body,
      parameters.parameters.firstOrNull?.name?.lexeme ?? 'json',
    ),
    MethodDeclaration(:final body) => _member(
      className,
      annotation,
      name,
      body,
      'this',
    ),
    _ => null,
  };

  /// The function json_serializable generates for the `fromJson` or
  /// `toJson` member [name] of [className], which drops the class's leading
  /// underscores.
  String _generated(String className, Token name) {
    final suffix = name.lexeme == 'fromJson' ? 'FromJson' : 'ToJson';
    return '_\$${className.replaceFirst(RegExp('^_*'), '')}$suffix';
  }

  /// Returns a finding for the `fromJson` or `toJson` member [name] with
  /// [body], unless [className] has a `@JsonSerializable` [annotation] and
  /// [body] returns a call to the generated function with [input] as its
  /// first argument.
  Finding? _member(
    String className,
    Annotation? annotation,
    Token name,
    FunctionBody body,
    String input,
  ) {
    final generated = _generated(className, name);
    final delegates = _delegates(body, generated, input);
    if (annotation != null && delegates) return null;
    final member = '$className.${name.lexeme}';
    final flag = name.lexeme == 'fromJson' ? 'createFactory' : 'createToJson';
    return Finding(
      offset: name.offset,
      symbol: member,
      message: switch (annotation) {
        null when delegates =>
          "`$member` delegates to `$generated`, but `$className` isn't "
              'annotated with `@JsonSerializable()`. Annotate it directly, '
              "since vaixell doesn't recognize aliases such as "
              '`@jsonSerializable`. Set `generated-json: off` if you use '
              'another generator, such as freezed.',
        null =>
          '`$member` is written by hand. Annotate `$className` with '
              '`@JsonSerializable()` and delegate to `$generated`. Use a '
              '`JsonConverter` for fields that need custom parsing.',
        _ when _disables(annotation, flag) =>
          '`$member` is written by hand. Remove `$flag: false` from '
              '`@JsonSerializable` and return `$generated($input)` instead. '
              'Use a `JsonConverter` for fields that need custom parsing.',
        _ =>
          '`$member` is written by hand. Return `$generated($input)` '
              'instead. Use a `JsonConverter` for fields that need custom '
              'parsing.',
      },
    );
  }

  /// Whether [body] only returns a call to [generated] with [input] as its
  /// first argument.
  bool _delegates(FunctionBody body, String generated, String input) {
    final call = switch (body) {
      ExpressionFunctionBody(:final expression) => expression,
      BlockFunctionBody(
        block: Block(statements: [ReturnStatement(:final expression?)]),
      ) =>
        expression,
      _ => null,
    };
    return switch (call) {
      MethodInvocation(
        target: null,
        :final methodName,
        argumentList: ArgumentList(arguments: [final Expression first, ...]),
      ) =>
        methodName.name == generated && _isInput(first, input),
      _ => false,
    };
  }

  /// Whether [argument] is [input], optionally null-checked or cast, as in
  /// `json! as Map<String, dynamic>`.
  bool _isInput(Expression argument, String input) => switch (argument) {
    ThisExpression() => input == 'this',
    SimpleIdentifier(:final name) => name == input,
    AsExpression(:final expression) ||
    PostfixExpression(
      operand: final expression,
      operator: Token(type: TokenType.BANG),
    ) => _isInput(expression, input),
    _ => false,
  };

  Annotation? _annotation(List<Annotation> metadata) => metadata
      .where(
        (annotation) => switch (annotation.name) {
          SimpleIdentifier(name: 'JsonSerializable') => true,
          PrefixedIdentifier(
            identifier: SimpleIdentifier(name: 'JsonSerializable'),
          ) =>
            true,
          _ => false,
        },
      )
      .firstOrNull;

  /// Whether [annotation] sets [flag] to `false`, as in
  /// `@JsonSerializable(createToJson: false)`, so the function isn't
  /// generated.
  bool _disables(Annotation annotation, String flag) =>
      annotation.arguments?.arguments.any(
        (argument) => switch (argument) {
          NamedArgument(
            :final name,
            argumentExpression: BooleanLiteral(value: false),
          ) =>
            name.lexeme == flag,
          _ => false,
        },
      ) ??
      false;
}
