// PROTOTYPE: await-receiver, raw-json and generated-json rewritten on the
// model in model.dart, for discussion on
// https://github.com/marcossevilla/vaixell/issues/36. Never merged.
//
// `Finding` keeps today's shape (#41). `enclosingSymbol` stands in for
// whatever "Where finding symbols come from" (#37) decides. Behavior matches
// packages/vaixell/lib/src/rules/, which prototype/test checks by running
// today's tests against these rules.

// ignore_for_file: public_member_api_docs

import 'package:vaixell/src/rules/rule.dart' show Finding;

import 'model.dart';

/// A rule written against the model.
abstract base class ModelRule {
  const ModelRule();

  String get id;

  List<Finding> check(DartFile file);
}

/// Today's `EnclosingDeclaration.symbolOf`, from the model.
String? enclosingSymbol(Declaration? declaration, Member? member) {
  String named(String name, FunctionKind kind) =>
      kind == FunctionKind.setter ? '$name=' : name;
  final memberName = switch (member) {
    Method(:final name, :final kind) => named(name, kind),
    Constructor(:final name) => name ?? 'new',
    Field(:final name) => name,
    null => null,
  };
  return switch (declaration) {
    null => null,
    TypeDeclaration(:final name) => [
      name ?? '<unnamed>',
      ?memberName,
    ].join('.'),
    TopLevelFunction(:final name, :final kind) => named(name, kind),
    TopLevelVariable(:final name) => name,
  };
}

/// Was: a `RecursiveAstVisitor`, a walk up `parent` through parentheses and
/// casts, and a switch over five parent node types.
final class AwaitReceiverRule extends ModelRule {
  const AwaitReceiverRule();

  @override
  String get id => 'await-receiver';

  @override
  List<Finding> check(DartFile file) => [
    for (final expression in file.expressions)
      if (expression case Await(
        use: ReceiverUse() || NullCheckUse(),
        :final operand,
      ))
        Finding(
          offset: expression.offset,
          message:
              '`await` result is used as a receiver. '
              'Assign it to a local variable first.',
          symbol: switch ((
            enclosingSymbol(expression.declaration, expression.member),
            _nameOf(operand),
          )) {
            (final enclosing, final name?) => '${enclosing ?? ''}@$name',
            (final enclosing, null) => enclosing,
          },
        ),
  ];

  String? _nameOf(Expression expression) => switch (expression) {
    MethodCall(:final name) || Reference(:final name) => name,
    FunctionCall(callee: final inner) ||
    Parenthesized(expression: final inner) => _nameOf(inner),
    _ => null,
  };
}

/// Was: a `RecursiveAstVisitor` that skipped JSON members, a switch over
/// call targets, a walk up `parent` and an unresolved-AST workaround for
/// `new User.fromJson`.
final class RawJsonRule extends ModelRule {
  const RawJsonRule();

  static const String _decodeAdvice =
      'Deserialize JSON in a `fromJson` constructor.';
  static const String _encodeAdvice = 'Serialize JSON in a `toJson` method.';

  static const Map<String, (String, String)> _calls = {
    'jsonDecode': ('decode', _decodeAdvice),
    'jsonEncode': ('encode', _encodeAdvice),
    'json.decode': ('decode', _decodeAdvice),
    'json.encode': ('encode', _encodeAdvice),
  };

  @override
  String get id => 'raw-json';

  @override
  List<Finding> check(DartFile file) {
    if (file.directories.contains('models')) return const [];
    final castsForFromJson = {
      for (final expression in file.expressions)
        if (expression case Cast(:final type) when _feedsFromJson(expression))
          type.offset,
    };
    return [
      for (final expression in file.expressions)
        if (expression case MethodCall() when !_inJsonMember(expression.member))
          if (_calls[_written(expression)] case (final kind, final advice)
              when !_handsOffToModel(expression, kind))
            _finding(
              expression.offset,
              enclosingSymbol(expression.declaration, expression.member),
              kind,
              '`${_written(expression)}` is not allowed outside model '
              'classes. $advice',
            ),
      for (final type in file.typeReferences)
        if (!_inJsonMember(type.member) &&
            _isRawJsonMap(type) &&
            !castsForFromJson.contains(type.offset))
          _finding(
            type.offset,
            enclosingSymbol(type.declaration, type.member),
            'map',
            '`Map<String, dynamic>` is not allowed outside model classes. '
                'Use a model class with `fromJson` and `toJson`.',
          ),
    ]..sort((a, b) => a.offset.compareTo(b.offset));
  }

  bool _inJsonMember(Member? member) => switch (member) {
    Constructor(name: 'fromJson') ||
    Method(name: 'fromJson' || 'toJson') => true,
    _ => false,
  };

  /// How [call] is written, when it's `name(…)`, `prefix.name(…)`,
  /// `json.name(…)` or `prefix.json.name(…)`.
  String? _written(MethodCall call) => switch (call.target) {
    Reference(target: null, name: 'json') ||
    Reference(
      target: Reference(target: null),
      name: 'json',
      operator: AccessOperator.period,
    ) => 'json.${call.name}',
    null || Reference(target: null) => call.name,
    _ => null,
  };

  bool _handsOffToModel(MethodCall call, String kind) => kind == 'decode'
      ? _feedsFromJson(call)
      : switch (call.arguments) {
          [Argument(name: null, :final value), ...] => !_isCollection(value),
          _ => false,
        };

  bool _feedsFromJson(Expression expression) => switch (expression.use) {
    ArgumentUse(
      name: null,
      call: MethodCall(name: 'fromJson') || InstanceCreation(name: 'fromJson'),
    ) =>
      true,
    _ => false,
  };

  bool _isCollection(Expression expression) => switch (expression) {
    CollectionLiteral() => true,
    Parenthesized(:final expression) => _isCollection(expression),
    _ => false,
  };

  bool _isRawJsonMap(TypeReference type) => switch (type) {
    TypeReference(
      name: 'Map',
      typeArguments: [
        TypeReference(name: 'String'),
        TypeReference(name: 'dynamic'),
      ],
    ) =>
      true,
    _ => false,
  };

  Finding _finding(int offset, String? enclosing, String kind, String m) =>
      Finding(offset: offset, message: m, symbol: '${enclosing ?? ''}@$kind');
}

/// Was: switches over AST members, bodies, invocations, identifiers and
/// tokens.
final class GeneratedJsonRule extends ModelRule {
  const GeneratedJsonRule();

  @override
  String get id => 'generated-json';

  @override
  List<Finding> check(DartFile file) => [
    for (final declaration in file.declarations)
      if (declaration case ClassDeclaration(:final name?))
        for (final member in _jsonMembers(declaration))
          ?_check(name, _annotation(declaration), member)
      else if (declaration case EnumDeclaration(:final name?))
        for (final member in _jsonMembers(declaration)) _enum(name, member),
  ];

  /// `fromJson` constructors, static `fromJson` methods and `toJson`
  /// methods for the type itself, in source order.
  List<Member> _jsonMembers(TypeDeclaration type) => <Member>[
    for (final constructor in type.constructors)
      if (constructor.name == 'fromJson' && !constructor.isExternal)
        constructor,
    for (final method in type.methods)
      if (!method.isAbstract && method.kind == FunctionKind.function)
        if ((method.name == 'fromJson' && method.isStatic) ||
            (method.name == 'toJson' && !_convertsValue(method)))
          method,
  ]..sort((a, b) => a.offset.compareTo(b.offset));

  bool _convertsValue(Method toJson) =>
      switch (toJson.parameters.where((p) => p.isPositional).firstOrNull) {
        final parameter? => !parameter.isFunction,
        null => false,
      };

  Finding _enum(String enumName, Member member) => Finding(
    offset: member.offset,
    symbol: '$enumName.${_nameOf(member)}',
    message:
        '`$enumName.${_nameOf(member)}` is written by hand. Annotate `$enumName` '
        'with `@JsonEnum()` and its values with `@JsonValue` instead.',
  );

  Finding? _check(String className, Annotation? annotation, Member member) =>
      switch (member) {
        Method(isStatic: true, name: 'fromJson') => Finding(
          offset: member.offset,
          symbol: '$className.fromJson',
          message:
              '`$className.fromJson` is a method. Make it a factory '
              'constructor, `factory $className.fromJson(Map<String, dynamic> '
              'json) => ${_generated(className, 'fromJson')}(json);`.',
        ),
        Constructor(:final returnExpression, :final parameters) => _member(
          className,
          annotation,
          member.offset,
          'fromJson',
          returnExpression,
          parameters.firstOrNull?.name ?? 'json',
        ),
        Method(:final name, :final returnExpression) => _member(
          className,
          annotation,
          member.offset,
          name,
          returnExpression,
          'this',
        ),
        Field() => null,
      };

  String _generated(String className, String name) {
    final suffix = name == 'fromJson' ? 'FromJson' : 'ToJson';
    return '_\$${className.replaceFirst(RegExp('^_*'), '')}$suffix';
  }

  Finding? _member(
    String className,
    Annotation? annotation,
    int offset,
    String name,
    Expression? returned,
    String input,
  ) {
    final generated = _generated(className, name);
    final delegates = switch (returned) {
      MethodCall(
        target: null,
        name: final called,
        arguments: [Argument(name: null, :final value), ...],
      ) =>
        called == generated && _isInput(value, input),
      _ => false,
    };
    if (annotation != null && delegates) return null;
    final member = '$className.$name';
    final flag = name == 'fromJson' ? 'createFactory' : 'createToJson';
    return Finding(
      offset: offset,
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

  String _nameOf(Member member) => switch (member) {
    Method(:final name) => name,
    _ => 'fromJson',
  };

  bool _isInput(Expression argument, String input) => switch (argument) {
    This() => input == 'this',
    Reference(target: null, :final name) => name == input,
    Cast(:final operand) ||
    NullCheck(:final operand) => _isInput(operand, input),
    _ => false,
  };

  Annotation? _annotation(TypeDeclaration type) =>
      type.annotations.where((a) => a.name == 'JsonSerializable').firstOrNull;

  bool _disables(Annotation annotation, String flag) => annotation.arguments
      .any((a) => a.name == flag && a.isLiteral && a.literal == false);
}
