// PROTOTYPE: await-receiver, raw-json and generated-json composed from the
// mixins in rule.dart and written against model.dart, for
// https://github.com/marcossevilla/vaixell/issues/36. Never merged. They
// behave exactly like packages/vaixell/lib/src/rules/, which prototype/test
// checks.
//
// What a rule needs to know about the code is written as file-private
// extension getters, so checks read as patterns over named facts, as in
// `TypeReference(isStringDynamicMap: true)`.

import 'model.dart';
import 'rule.dart';

// --- await-receiver ----------------------------------------------------------

/// Reports an `await` whose result is used as a receiver, as in
/// `(await f).x` or `(await f)!`.
final class const AwaitReceiverRule() extends ModelRule with ChecksExpressions {
  @override
  String get id => 'await-receiver';

  @override
  Finding? checkExpression(Expression expression) => switch (expression) {
    Await(use: ReceiverUse() || NullCheckUse(), :final operand) => Finding.at(
      expression,
      qualifier: operand.calledName,
      message:
          '`await` result is used as a receiver. '
          'Assign it to a local variable first.',
    ),
    _ => null,
  };
}

extension on Expression {
  /// The name of the call or getter this is, as in `fetch` for
  /// `api.fetch()` or `api.fetch`, if any.
  String? get calledName => switch (unparenthesized) {
    MethodCall(:final name) || Reference(:final name) => name,
    FunctionCall(:final callee) => callee.calledName,
    _ => null,
  };
}

// --- raw-json ----------------------------------------------------------------

/// Reports `jsonDecode`, `jsonEncode`, `json.decode`, `json.encode` and
/// `Map<String, dynamic>` outside model classes.
final class const RawJsonRule()
    extends ModelRule
    with ChecksExpressions, ChecksTypeReferences, SkipsDirectories {
  static const Map<String, String> _advice = {
    'decode': 'Deserialize JSON in a `fromJson` constructor.',
    'encode': 'Serialize JSON in a `toJson` method.',
  };

  @override
  String get id => 'raw-json';

  @override
  Set<String> get skippedDirectories => const {'models'};

  @override
  Finding? checkExpression(Expression expression) => switch (expression) {
    MethodCall(
      isInJsonMember: false,
      jsonKind: final kind?,
      handsOffToModel: false,
      :final writtenAs,
    ) =>
      Finding.at(
        expression,
        qualifier: kind,
        message:
            '`$writtenAs` is not allowed outside model classes. '
            '${_advice[kind]}',
      ),
    _ => null,
  };

  @override
  Finding? checkTypeReference(TypeReference type) => switch (type) {
    TypeReference(
      isInJsonMember: false,
      isStringDynamicMap: true,
      cast: null || Cast(isPassedToFromJson: false),
    ) =>
      Finding.at(
        type,
        qualifier: 'map',
        message:
            '`Map<String, dynamic>` is not allowed outside model classes. '
            'Use a model class with `fromJson` and `toJson`.',
      ),
    _ => null,
  };
}

extension on Enclosed {
  /// Whether this is in a `fromJson` constructor or a `fromJson` or
  /// `toJson` method, where raw JSON belongs.
  bool get isInJsonMember => switch (member) {
    Constructor(name: 'fromJson') ||
    Method(name: 'fromJson' || 'toJson') => true,
    _ => false,
  };
}

extension on MethodCall {
  /// `jsonDecode` for `jsonDecode(…)` or `prefix.jsonDecode(…)`, and
  /// `json.decode` for `json.decode(…)` or `prefix.json.decode(…)`.
  String? get writtenAs => switch (target) {
    null || Reference(target: null, name: != 'json') => name,
    Reference(target: null, name: 'json') ||
    Reference(
      target: Reference(target: null),
      operator: AccessOperator.period,
      name: 'json',
    ) => 'json.$name',
    _ => null,
  };

  /// `decode` or `encode` for a call to dart:convert's JSON functions.
  String? get jsonKind => switch (writtenAs) {
    'jsonDecode' || 'json.decode' => 'decode',
    'jsonEncode' || 'json.encode' => 'encode',
    _ => null,
  };

  /// Whether this hands JSON straight to or from a model: a decode passed
  /// to `fromJson`, or an encode of something other than a collection
  /// literal, which calls its `toJson`.
  bool get handsOffToModel => switch ((jsonKind, arguments)) {
    ('decode', _) => isPassedToFromJson,
    ('encode', [Argument(name: null, :final value), ...]) =>
      value.unparenthesized is! CollectionLiteral,
    _ => false,
  };
}

extension on Expression {
  /// Whether this, looking through parentheses and casts, is a positional
  /// argument of a `fromJson` call.
  bool get isPassedToFromJson => switch (use) {
    ArgumentUse(
      name: null,
      call: MethodCall(name: 'fromJson') || InstanceCreation(name: 'fromJson'),
    ) =>
      true,
    _ => false,
  };
}

extension on TypeReference {
  bool get isStringDynamicMap => switch (this) {
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

// --- generated-json ----------------------------------------------------------

/// Reports `fromJson` and `toJson` members that json_serializable doesn't
/// generate.
final class const GeneratedJsonRule() extends ModelRule with ChecksMembers {
  @override
  String get id => 'generated-json';

  @override
  Finding? checkMember(TypeDeclaration type, Member member) =>
      member.isJsonMember ? _JsonMember(type, member).finding : null;
}

extension on Member {
  /// A `fromJson` constructor, a static `fromJson` method or a `toJson`
  /// method that converts the type itself.
  bool get isJsonMember => switch (this) {
    Constructor(name: 'fromJson', isExternal: false) => true,
    Method(isAbstract: true) || Method(kind: != FunctionKind.function) => false,
    Method(name: 'fromJson', isStatic: true) => true,
    Method(name: 'toJson', convertsAnotherValue: false) => true,
    _ => false,
  };

  /// `fromJson` or `toJson`.
  String get jsonName => switch (this) {
    Method(:final name) => name,
    _ => 'fromJson',
  };
}

extension on Method {
  /// A `toJson(value)`, as in HydratedBloc or a `JsonConverter`. A model's
  /// `toJson` only takes functions, with `genericArgumentFactories`.
  bool get convertsAnotherValue =>
      switch (parameters.where((p) => p.isPositional).firstOrNull) {
        final parameter? => !parameter.isFunction,
        null => false,
      };
}

/// A `fromJson` or `toJson` member of a type, and what generated-json
/// reports about it.
sealed class _JsonMember {
  factory(TypeDeclaration type, Member member) => switch ((type, member)) {
    (final EnumDeclaration type, _) => _InEnum(type, member),
    (final ClassDeclaration type, Method(isStatic: true, name: 'fromJson')) =>
      _StaticFromJson(type, member),
    (final ClassDeclaration type, _) => _InClass(type, member),
    _ => const _Unchecked(),
  };

  Finding? get finding;
}

/// Mixins, extensions and extension types can't be annotated with
/// `@JsonSerializable`.
final class const _Unchecked() implements _JsonMember {
  @override
  Finding? get finding => null;
}

/// Enums use `@JsonEnum` and `@JsonValue` instead, whatever the body.
final class _InEnum(final EnumDeclaration type, final Member member)
    implements _JsonMember {
  String get symbol => member.symbol!;

  @override
  Finding get finding => Finding(
    offset: member.offset,
    symbol: symbol,
    message:
        '`$symbol` is written by hand. Annotate `${type.name}` with '
        '`@JsonEnum()` and its values with `@JsonValue` instead.',
  );
}

/// A class's `fromJson` constructor or `toJson` method, which should only
/// return a call to the function json_serializable generates.
base class _InClass(final ClassDeclaration type, final Member member)
    implements _JsonMember {
  String get name => member.jsonName;

  String get symbol => member.symbol!;

  /// `_$UserFromJson` for `User.fromJson`. Leading underscores are dropped.
  String get generated =>
      '_\$${type.name.replaceFirst(RegExp('^_*'), '')}'
      '${name == 'fromJson' ? 'FromJson' : 'ToJson'}';

  /// What the body should pass to [generated].
  String get input => switch (member) {
    Constructor(:final parameters) => parameters.firstOrNull?.name ?? 'json',
    _ => 'this',
  };

  Expression? get body => switch (member) {
    Constructor(:final returnExpression) ||
    Method(:final returnExpression) => returnExpression,
    Field() => null,
  };

  Annotation? get annotation =>
      type.annotations.where((a) => a.name == 'JsonSerializable').firstOrNull;

  /// The `@JsonSerializable` flag that turns [generated] off.
  String get flag => name == 'fromJson' ? 'createFactory' : 'createToJson';

  bool get isTurnedOff =>
      annotation?.arguments.any(
        (a) => a.name == flag && a.isLiteral && a.literal == false,
      ) ??
      false;

  /// Whether [body] is `generated(input, …)`, where the input may be cast
  /// or null-checked, as in `_$UserFromJson(json! as Map)`.
  bool get delegates => switch (body) {
    MethodCall(
      target: null,
      :final name,
      arguments: [Argument(name: null, :final value), ...],
    ) =>
      name == generated && value.isInput(input),
    _ => false,
  };

  @override
  Finding? get finding => annotation != null && delegates
      ? null
      : Finding(offset: member.offset, symbol: symbol, message: message);

  String get message => switch (annotation) {
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
    _ when isTurnedOff =>
      '`$symbol` is written by hand. Remove `$flag: false` from '
          '`@JsonSerializable` and return `$generated($input)` instead. '
          'Use a `JsonConverter` for fields that need custom parsing.',
    _ =>
      '`$symbol` is written by hand. Return `$generated($input)` instead. '
          'Use a `JsonConverter` for fields that need custom parsing.',
  };
}

/// json_serializable expects a factory constructor, so a static `fromJson`
/// is reported whatever its body.
final class _StaticFromJson(super.type, super.member) extends _InClass {
  @override
  Finding get finding => Finding(
    offset: member.offset,
    symbol: symbol,
    message:
        '`$symbol` is a method. Make it a factory constructor, '
        '`factory ${type.name}.fromJson(Map<String, dynamic> json) => '
        '$generated(json);`.',
  );
}

extension on Expression {
  /// Whether this is [input] (`this` or a name), optionally cast or
  /// null-checked. Parentheses don't count.
  bool isInput(String input) => switch (this) {
    This() => input == 'this',
    Reference(target: null, :final name) => name == input,
    Cast(:final operand) || NullCheck(:final operand) => operand.isInput(input),
    _ => false,
  };
}
