// PROTOTYPE: await-receiver, raw-json and generated-json written against
// model.dart, for https://github.com/marcossevilla/vaixell/issues/36. Never
// merged. They behave exactly like packages/vaixell/lib/src/rules/, which
// prototype/test checks.

import 'package:vaixell/src/rules/rule.dart' show Finding;

import 'model.dart';

/// A rule written against the model.
abstract base class const ModelRule() {
  String get id;

  List<Finding> check(DartFile file);
}

/// `Container.member`, `member`, `Container` or `null` for where [code]
/// sits, as today's ids spell it. A stand-in for whatever #37 decides.
String? enclosingSymbol(Enclosed code) {
  final container = switch (code.declaration) {
    TypeDeclaration(:final name) => name ?? '<unnamed>',
    TopLevelFunction(:final name, kind: FunctionKind.setter) => '$name=',
    TopLevelFunction(:final name) || TopLevelVariable(:final name) => name,
    null => null,
  };
  final member = switch (code.member) {
    Method(:final name, kind: FunctionKind.setter) => '$name=',
    Method(:final name) || Field(:final name) => name,
    Constructor(:final name) => name ?? 'new',
    null => null,
  };
  return member == null ? container : '$container.$member';
}

/// Reports an `await` whose result is used as a receiver, as in
/// `(await f).x` or `(await f)!`.
final class const AwaitReceiverRule() extends ModelRule {
  @override
  String get id => 'await-receiver';

  @override
  List<Finding> check(DartFile file) => [
    for (final awaited in file.expressions.whereType<Await>())
      if (awaited.use case ReceiverUse() || NullCheckUse())
        Finding(
          offset: awaited.offset,
          symbol: _symbol(awaited),
          message:
              '`await` result is used as a receiver. '
              'Assign it to a local variable first.',
        ),
  ];

  /// `Foo.bar@fetch`: where the await is, and what it awaits.
  String? _symbol(Await awaited) {
    final enclosing = enclosingSymbol(awaited);
    return switch (_awaitedName(awaited.operand)) {
      final name? => '${enclosing ?? ''}@$name',
      null => enclosing,
    };
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
final class const RawJsonRule() extends ModelRule {
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
  List<Finding> check(DartFile file) {
    if (file.directories.contains('models')) return const [];
    return [
      for (final call in file.expressions.whereType<MethodCall>())
        if (!_isInJsonMember(call)) ?_checkCall(call),
      for (final type in file.typeReferences)
        if (!_isInJsonMember(type)) ?_checkType(type),
    ]..sort((a, b) => a.offset.compareTo(b.offset));
  }

  Finding? _checkCall(MethodCall call) {
    final written = _writtenAs(call);
    if (_calls[written] case (final kind, final advice)
        when !_handsOffToModel(call, kind)) {
      return _finding(
        call,
        kind,
        '`$written` is not allowed outside model classes. $advice',
      );
    }
    return null;
  }

  Finding? _checkType(TypeReference type) {
    if (!_isStringDynamicMap(type)) return null;
    if (type.cast case final cast? when _isPassedToFromJson(cast)) return null;
    return _finding(
      type,
      'map',
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

  Finding _finding(Enclosed code, String kind, String message) => Finding(
    offset: code.offset,
    symbol: '${enclosingSymbol(code) ?? ''}@$kind',
    message: message,
  );
}

/// Reports `fromJson` and `toJson` members that json_serializable doesn't
/// generate.
final class const GeneratedJsonRule() extends ModelRule {
  @override
  String get id => 'generated-json';

  @override
  List<Finding> check(DartFile file) => [
    for (final declaration in file.declarations)
      ...switch (declaration) {
        ClassDeclaration() => _checkClass(declaration),
        EnumDeclaration() => _checkEnum(declaration),
        _ => const <Finding>[],
      },
  ];

  List<Finding> _checkClass(ClassDeclaration type) => [
    for (final member in _jsonMembers(type))
      ?switch (member) {
        Method(isStatic: true, name: 'fromJson') => _staticFromJson(
          type,
          member,
        ),
        Constructor(:final parameters, :final returnExpression) => _checkBody(
          type,
          member,
          name: 'fromJson',
          body: returnExpression,
          input: parameters.firstOrNull?.name ?? 'json',
        ),
        Method(:final name, :final returnExpression) => _checkBody(
          type,
          member,
          name: name,
          body: returnExpression,
          input: 'this',
        ),
        Field() => null,
      },
  ];

  /// Enums use `@JsonEnum` and `@JsonValue` instead, whatever the body.
  List<Finding> _checkEnum(EnumDeclaration type) => [
    for (final member in _jsonMembers(type))
      Finding(
        offset: member.offset,
        symbol: '${type.name}.${_nameOf(member)}',
        message:
            '`${type.name}.${_nameOf(member)}` is written by hand. Annotate '
            '`${type.name}` with `@JsonEnum()` and its values with '
            '`@JsonValue` instead.',
      ),
  ];

  /// `fromJson` constructors, static `fromJson` methods and `toJson`
  /// methods that convert the type itself, in source order.
  List<Member> _jsonMembers(TypeDeclaration type) => [
    for (final constructor in type.constructors)
      if (constructor.name == 'fromJson' && !constructor.isExternal)
        constructor,
    for (final method in type.methods)
      if (!method.isAbstract && method.kind == FunctionKind.function)
        if ((method.name == 'fromJson' && method.isStatic) ||
            (method.name == 'toJson' && !_convertsAnotherValue(method)))
          method,
  ]..sort((a, b) => a.offset.compareTo(b.offset));

  /// A `toJson(value)`, as in HydratedBloc or a `JsonConverter`. A model's
  /// `toJson` only takes functions, with `genericArgumentFactories`.
  bool _convertsAnotherValue(Method toJson) =>
      switch (toJson.parameters.where((p) => p.isPositional).firstOrNull) {
        final parameter? => !parameter.isFunction,
        null => false,
      };

  Finding _staticFromJson(ClassDeclaration type, Method method) => Finding(
    offset: method.offset,
    symbol: '${type.name}.fromJson',
    message:
        '`${type.name}.fromJson` is a method. Make it a factory constructor, '
        '`factory ${type.name}.fromJson(Map<String, dynamic> json) => '
        '${_generated(type, 'fromJson')}(json);`.',
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
    final generated = _generated(type, name);
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
  String _generated(ClassDeclaration type, String name) {
    final suffix = name == 'fromJson' ? 'FromJson' : 'ToJson';
    return '_\$${type.name.replaceFirst(RegExp('^_*'), '')}$suffix';
  }

  Annotation? _jsonSerializable(ClassDeclaration type) =>
      type.annotations.where((a) => a.name == 'JsonSerializable').firstOrNull;

  /// Whether [annotation] sets [flag] to `false`, so the generated function
  /// doesn't exist.
  bool _disables(Annotation annotation, String flag) => annotation.arguments
      .any((a) => a.name == flag && a.isLiteral && a.literal == false);

  String _nameOf(Member member) => switch (member) {
    Method(:final name) => name,
    _ => 'fromJson',
  };
}
