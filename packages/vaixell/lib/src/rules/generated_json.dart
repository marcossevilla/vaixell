import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Reports `fromJson` and `toJson` members that json_serializable doesn't
/// generate.
///
/// A `fromJson` constructor or `toJson` method passes when its class is
/// annotated with `@JsonSerializable` and its body only returns
/// `_$<Class>FromJson(json, …)` or `_$<Class>ToJson(this, …)`, where
/// `<Class>` drops any leading underscores. A static `fromJson` method and
/// a generative `fromJson` constructor are always reported, since
/// json_serializable expects a factory constructor.
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
final class const GeneratedJsonRule() extends Rule with ChecksMembers {
  /// Creates the rule.
  this;

  @override
  String get id => 'generated-json';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Finding? checkMember(TypeDeclaration type, Member member) =>
      _isJsonMember(member) ? _JsonMember(type, member).finding : null;

  /// Whether [member] is a `fromJson` constructor, a static `fromJson`
  /// method or a `toJson` method that converts the type itself.
  bool _isJsonMember(Member member) => switch (member) {
    Constructor(name: 'fromJson', isExternal: false) => true,
    Method(isAbstract: true) || Method(kind: != FunctionKind.function) => false,
    Method(name: 'fromJson', isStatic: true) => true,
    Method(name: 'toJson', :final parameters) => !_convertsValue(parameters),
    _ => false,
  };

  /// Whether the first positional parameter in [parameters] is a value
  /// rather than a function. A `toJson` that takes a value to convert, as
  /// in HydratedBloc or a `JsonConverter`, isn't a model's `toJson`, which
  /// only takes functions with `genericArgumentFactories`.
  bool _convertsValue(List<Parameter> parameters) =>
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
    (final ClassDeclaration type, Constructor(isFactory: false)) =>
      _GenerativeFromJson(type, member),
    (
      final ClassDeclaration type,
      Constructor(:final returnExpression) || Method(:final returnExpression),
    ) =>
      _InClass(type, member, body: returnExpression),
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
  @override
  Finding get finding => Finding.at(
    member,
    message:
        '`${member.symbol}` is written by hand. Annotate `${type.name}` with '
        '`@JsonEnum()` and its values with `@JsonValue` instead.',
  );
}

/// A class's `fromJson` constructor or `toJson` method, which should only
/// return a call to the function json_serializable generates.
///
/// [body] is what the member returns, if it only returns something.
base class _InClass(
  final ClassDeclaration type,
  final Member member, {
  final Expression? body,
}) implements _JsonMember {
  /// `fromJson` or `toJson`.
  String get name => switch (member) {
    Method(:final name) => name,
    _ => 'fromJson',
  };

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

  Annotation? get annotation =>
      type.annotations.where((a) => a.name == 'JsonSerializable').firstOrNull;

  /// The `@JsonSerializable` flag that turns [generated] off.
  String get flag => name == 'fromJson' ? 'createFactory' : 'createToJson';

  /// Whether [annotation] sets [flag] to `false`, as in
  /// `@JsonSerializable(createToJson: false)`.
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
      name == generated && _isInput(value),
    _ => false,
  };

  /// Whether [expression] is [input] (`this` or a name), optionally cast or
  /// null-checked. Parentheses don't count.
  bool _isInput(Expression expression) => switch (expression) {
    This() => input == 'this',
    Reference(target: null, :final name) => name == input,
    Cast(:final operand) || NullCheck(:final operand) => _isInput(operand),
    _ => false,
  };

  /// The factory constructor json_serializable expects, taking [parameter].
  String factoryTaking(String parameter) =>
      'factory ${type.name}.fromJson(Map<String, dynamic> $parameter) => '
      '$generated($parameter);';

  @override
  Finding? get finding => annotation != null && delegates
      ? null
      : Finding.at(member, message: message);

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
  Finding get finding => Finding.at(
    member,
    message:
        '`$symbol` is a method. Make it a factory constructor, '
        '`${factoryTaking('json')}`.',
  );
}

/// A generative `fromJson` constructor, including a primary one, can't
/// return what json_serializable generates, so it's reported whatever its
/// body, with how to make it a factory.
final class _GenerativeFromJson(super.type, super.member) extends _InClass {
  @override
  Finding get finding => Finding.at(
    member,
    message:
        "`$symbol` is a generative constructor, which can't return the "
        'generated function. $_steps a factory constructor, '
        '`${factoryTaking(input)}`.',
  );

  /// The steps before the factory constructor, ending in "make it".
  String get _steps => switch (annotation) {
    null => 'Annotate `${type.name}` with `@JsonSerializable()` and make it',
    _ when isTurnedOff =>
      'Remove `$flag: false` from `@JsonSerializable` and make it',
    _ => 'Make it',
  };
}
