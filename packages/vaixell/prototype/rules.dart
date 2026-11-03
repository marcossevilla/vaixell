// PROTOTYPE: await-receiver, raw-json and generated-json composed from the
// mixins in rule.dart and written against model.dart, for
// https://github.com/marcossevilla/vaixell/issues/36. Never merged. They
// behave exactly like packages/vaixell/lib/src/rules/, which prototype/test
// checks.

import 'package:vaixell/src/rules/rule.dart' show Finding;

import 'model.dart';
import 'rule.dart';

/// Reports an `await` whose result is used as a receiver, as in
/// `(await f).x` or `(await f)!`.
final class const AwaitReceiverRule()
    extends ModelRule
    with ChecksExpressions, NamesFindings {
  @override
  String get id => 'await-receiver';

  @override
  Finding? checkExpression(Expression expression) {
    if (expression case Await(
      use: ReceiverUse() || NullCheckUse(),
      :final operand,
    )) {
      return Finding(
        offset: expression.offset,
        symbol: symbolOf(expression, at: _awaitedName(operand)),
        message:
            '`await` result is used as a receiver. '
            'Assign it to a local variable first.',
      );
    }
    return null;
  }

  /// The name of the call or getter in [expression], if any.
  String? _awaitedName(Expression expression) =>
      switch (expression.unparenthesized) {
        MethodCall(:final name) || Reference(:final name) => name,
        FunctionCall(:final callee) => _awaitedName(callee),
        _ => null,
      };
}

/// Reports `jsonDecode`, `jsonEncode`, `json.decode`, `json.encode` and
/// `Map<String, dynamic>` outside model classes.
final class const RawJsonRule()
    extends ModelRule
    with
        ChecksExpressions,
        ChecksTypeReferences,
        SkipsDirectories,
        NamesFindings {
  static const _decodeAdvice = 'Deserialize JSON in a `fromJson` constructor.';
  static const _encodeAdvice = 'Serialize JSON in a `toJson` method.';

  /// The kind and advice for each call, by how it's written.
  static const Map<String, (String, String)> _calls = {
    'jsonDecode': ('decode', _decodeAdvice),
    'jsonEncode': ('encode', _encodeAdvice),
    'json.decode': ('decode', _decodeAdvice),
    'json.encode': ('encode', _encodeAdvice),
  };

  @override
  String get id => 'raw-json';

  @override
  Set<String> get skippedDirectories => const {'models'};

  @override
  Finding? checkExpression(Expression expression) {
    if (expression is! MethodCall || _isInJsonMember(expression)) return null;
    final written = _writtenAs(expression);
    if (_calls[written] case (final kind, final advice)
        when !_handsOffToModel(expression, kind)) {
      return Finding(
        offset: expression.offset,
        symbol: symbolOf(expression, at: kind),
        message: '`$written` is not allowed outside model classes. $advice',
      );
    }
    return null;
  }

  @override
  Finding? checkTypeReference(TypeReference type) {
    if (_isInJsonMember(type) || !_isStringDynamicMap(type)) return null;
    if (type.cast case final cast? when _isPassedToFromJson(cast)) return null;
    return Finding(
      offset: type.offset,
      symbol: symbolOf(type, at: 'map'),
      message:
          '`Map<String, dynamic>` is not allowed outside model classes. '
          'Use a model class with `fromJson` and `toJson`.',
    );
  }

  /// Whether [code] is in a `fromJson` constructor or a `fromJson` or
  /// `toJson` method, where raw JSON belongs.
  bool _isInJsonMember(Enclosed code) => switch (code.member) {
    Constructor(name: 'fromJson') ||
    Method(name: 'fromJson' || 'toJson') => true,
    _ => false,
  };

  /// `jsonDecode` for `jsonDecode(…)` or `prefix.jsonDecode(…)`, and
  /// `json.decode` for `json.decode(…)` or `prefix.json.decode(…)`.
  String? _writtenAs(MethodCall call) => switch (call.target) {
    null || Reference(target: null, name: != 'json') => call.name,
    Reference(target: null, name: 'json') ||
    Reference(
      target: Reference(target: null),
      operator: AccessOperator.period,
      name: 'json',
    ) => 'json.${call.name}',
    _ => null,
  };

  /// Whether [call] hands JSON straight to or from a model: a decode passed
  /// to `fromJson`, or an encode of something other than a collection
  /// literal, which calls its `toJson`.
  bool _handsOffToModel(MethodCall call, String kind) {
    if (kind == 'decode') return _isPassedToFromJson(call);
    return switch (call.arguments) {
      [Argument(name: null, :final value), ...] =>
        value.unparenthesized is! CollectionLiteral,
      _ => false,
    };
  }

  bool _isPassedToFromJson(Expression expression) => switch (expression.use) {
    ArgumentUse(
      name: null,
      call: MethodCall(name: 'fromJson') || InstanceCreation(name: 'fromJson'),
    ) =>
      true,
    _ => false,
  };

  bool _isStringDynamicMap(TypeReference type) => switch (type) {
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
}

/// Reports `fromJson` and `toJson` members that json_serializable doesn't
/// generate.
final class const GeneratedJsonRule() extends ModelRule with ChecksMembers {
  @override
  String get id => 'generated-json';

  @override
  Finding? checkMember(TypeDeclaration type, Member member) {
    if (!_isJsonMember(member)) return null;
    return switch ((type, member)) {
      (final EnumDeclaration type, _) => _handWrittenInEnum(type.name, member),
      (
        final ClassDeclaration type,
        final Method method && Method(isStatic: true, name: 'fromJson'),
      ) =>
        _staticFromJson(type.name, method),
      (final ClassDeclaration type, final Constructor constructor) =>
        _checkBody(
          type,
          constructor,
          name: 'fromJson',
          body: constructor.returnExpression,
          input: constructor.parameters.firstOrNull?.name ?? 'json',
        ),
      (final ClassDeclaration type, final Method method) => _checkBody(
        type,
        method,
        name: method.name,
        body: method.returnExpression,
        input: 'this',
      ),
      _ => null,
    };
  }

  /// A `fromJson` constructor, a static `fromJson` method or a `toJson`
  /// method that converts the type itself.
  bool _isJsonMember(Member member) => switch (member) {
    Constructor(name: 'fromJson', isExternal: false) => true,
    Method(isAbstract: true) || Method(kind: != FunctionKind.function) => false,
    Method(name: 'fromJson', isStatic: true) => true,
    Method(name: 'toJson') => !_convertsAnotherValue(member),
    _ => false,
  };

  /// A `toJson(value)`, as in HydratedBloc or a `JsonConverter`. A model's
  /// `toJson` only takes functions, with `genericArgumentFactories`.
  bool _convertsAnotherValue(Method toJson) =>
      switch (toJson.parameters.where((p) => p.isPositional).firstOrNull) {
        final parameter? => !parameter.isFunction,
        null => false,
      };

  /// Enums use `@JsonEnum` and `@JsonValue` instead, whatever the body.
  Finding _handWrittenInEnum(String enumName, Member member) {
    final symbol = '$enumName.${member is Method ? member.name : 'fromJson'}';
    return Finding(
      offset: member.offset,
      symbol: symbol,
      message:
          '`$symbol` is written by hand. Annotate `$enumName` with '
          '`@JsonEnum()` and its values with `@JsonValue` instead.',
    );
  }

  Finding _staticFromJson(String className, Method method) => Finding(
    offset: method.offset,
    symbol: '$className.fromJson',
    message:
        '`$className.fromJson` is a method. Make it a factory constructor, '
        '`factory $className.fromJson(Map<String, dynamic> json) => '
        '${_generated(className, 'fromJson')}(json);`.',
  );

  /// Reports the `fromJson` or `toJson` member [name] unless [type] is
  /// annotated with `@JsonSerializable` and [body] delegates to the
  /// generated function, passing [input].
  Finding? _checkBody(
    ClassDeclaration type,
    Member member, {
    required String name,
    required Expression? body,
    required String input,
  }) {
    final annotation = _jsonSerializable(type);
    final generated = _generated(type.name, name);
    final delegates = _delegates(body, to: generated, passing: input);
    if (annotation != null && delegates) return null;

    final symbol = '${type.name}.$name';
    final flag = name == 'fromJson' ? 'createFactory' : 'createToJson';
    return Finding(
      offset: member.offset,
      symbol: symbol,
      message: switch (annotation) {
        null when delegates =>
          "`$symbol` delegates to `$generated`, but `${type.name}` isn't "
              'annotated with `@JsonSerializable()`. Annotate it directly, '
              "since vaixell doesn't recognize aliases such as "
              '`@jsonSerializable`. Set `generated-json: off` if you use '
              'another generator, such as freezed.',
        null =>
          '`$symbol` is written by hand. Annotate `${type.name}` with '
              '`@JsonSerializable()` and delegate to `$generated`. Use a '
              '`JsonConverter` for fields that need custom parsing.',
        _ when _disables(annotation, flag) =>
          '`$symbol` is written by hand. Remove `$flag: false` from '
              '`@JsonSerializable` and return `$generated($input)` instead. '
              'Use a `JsonConverter` for fields that need custom parsing.',
        _ =>
          '`$symbol` is written by hand. Return `$generated($input)` '
              'instead. Use a `JsonConverter` for fields that need custom '
              'parsing.',
      },
    );
  }

  /// Whether [body] is `generated(input, …)`, where the input may be
  /// cast or null-checked, as in `_$UserFromJson(json! as Map)`.
  bool _delegates(
    Expression? body, {
    required String to,
    required String passing,
  }) => switch (body) {
    MethodCall(
      target: null,
      :final name,
      arguments: [Argument(name: null, :final value), ...],
    ) =>
      name == to && _isInput(value, passing),
    _ => false,
  };

  bool _isInput(Expression expression, String input) => switch (expression) {
    This() => input == 'this',
    Reference(target: null, :final name) => name == input,
    Cast(:final operand) ||
    NullCheck(:final operand) => _isInput(operand, input),
    _ => false,
  };

  /// `_$UserFromJson` for `User.fromJson`. Leading underscores are dropped.
  String _generated(String className, String name) {
    final suffix = name == 'fromJson' ? 'FromJson' : 'ToJson';
    return '_\$${className.replaceFirst(RegExp('^_*'), '')}$suffix';
  }

  Annotation? _jsonSerializable(ClassDeclaration type) =>
      type.annotations.where((a) => a.name == 'JsonSerializable').firstOrNull;

  /// Whether [annotation] sets [flag] to `false`, so the generated function
  /// doesn't exist.
  bool _disables(Annotation annotation, String flag) => annotation.arguments
      .any((a) => a.name == flag && a.isLiteral && a.literal == false);
}
