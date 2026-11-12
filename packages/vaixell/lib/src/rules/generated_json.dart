import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Reports `fromJson` and `toJson` members that json_serializable doesn't
/// generate.
///
/// A `fromJson` constructor or `toJson` method passes when its class is
/// annotated with `@JsonSerializable` and its body only returns
/// `_$<Class>FromJson(json, …)` or `_$<Class>ToJson(this, …)`. Static
/// `fromJson` methods and generative `fromJson` constructors are always
/// reported. Enums' `fromJson` and `toJson` members are always reported
/// too, since enums use `@JsonEnum` and `@JsonValue`.
///
/// Abstract and external members aren't reported, and neither are helpers
/// that convert another value, such as HydratedBloc overrides and
/// `JsonConverter` implementations. Mixins, extensions and extension types
/// aren't checked, since they can't be annotated with `@JsonSerializable`.
final class const GeneratedJsonRule() extends Rule with ChecksMembers {
  /// Creates the rule.
  this;

  @override
  String get id => 'generated-json';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Finding? checkMember(TypeDeclaration type, Member member) {
    if (!_isJsonMember(member)) return null;
    return switch ((type, member)) {
      (EnumDeclaration(:final name), _) => Finding.at(
        member,
        message:
            '`${member.symbol}` is written by hand. Annotate `$name` with '
            '`@JsonEnum()` and its values with `@JsonValue` instead.',
      ),
      (final ClassDeclaration type, final FunctionMember member) => _ClassJson(
        type,
        member,
      ).finding,
      _ => null,
    };
  }

  /// Whether [member] is a `fromJson` constructor, a static `fromJson`
  /// method or a `toJson` method that converts the type itself.
  bool _isJsonMember(Member member) => switch (member) {
    Constructor(name: 'fromJson', isExternal: false) => true,
    Method(isAbstract: true) || Method(kind: != FunctionKind.function) => false,
    Method(name: 'fromJson', isStatic: true) => true,
    Method(name: 'toJson', :final parameters) => !_convertsValue(parameters),
    _ => false,
  };

  /// Whether a `toJson` with [parameters] converts the value passed first,
  /// rather than `this`. A function first, as `genericArgumentFactories`
  /// passes, still converts `this`.
  static bool _convertsValue(List<Parameter> parameters) =>
      switch (parameters.where((p) => p.isPositional).firstOrNull) {
        null => false,
        final first => !first.isFunction,
      };
}

/// A class's `fromJson` or `toJson`, and what generated-json says about it.
final class _ClassJson(
  final ClassDeclaration type,
  final FunctionMember member,
) {
  late final Annotation? annotation = type.annotationNamed('JsonSerializable');

  bool get isFromJson => member.name == 'fromJson';

  String get symbol => member.symbol!;

  /// `_$UserFromJson` for `User.fromJson`, dropping leading underscores as
  /// json_serializable does.
  String get generated =>
      '_\$${type.name.replaceFirst(_leadingUnderscores, '')}'
      '${isFromJson ? 'FromJson' : 'ToJson'}';

  /// What the body should pass to [generated]: `this` for `toJson`, and
  /// the first parameter, or `json`, for `fromJson`.
  String get input => switch (member) {
    _ when !isFromJson => 'this',
    Constructor(:final parameters) => parameters.firstOrNull?.name ?? 'json',
    _ => 'json',
  };

  /// The `@JsonSerializable` flag that turns [generated] off.
  String get flag => isFromJson ? 'createFactory' : 'createToJson';

  /// Whether [annotation] passes `flag: false`.
  bool get isTurnedOff => annotation?.argumentNamed(flag)?.literal == false;

  /// Whether the body only returns `generated(input, …)`, where the call
  /// may be parenthesized and the input parenthesized, cast or null-checked.
  bool get delegates => switch (member.returnExpression?.unparenthesized) {
    MethodCall(
      target: null,
      :final name,
      arguments: [Argument(name: null, :final value), ...],
    )
        when name == generated =>
      switch (value.unwrapped) {
        This() => input == 'this',
        Reference(target: null, :final name) => name == input,
        _ => false,
      },
    _ => false,
  };

  /// The factory constructor json_serializable expects.
  String get factory =>
      'factory ${type.name}.fromJson(Map<String, dynamic> $input) => '
      '$generated($input);';

  /// Whether [member] is a static `fromJson` method, which json_serializable
  /// can't use whatever its body.
  bool get isStaticFromJson => isFromJson && member is Method;

  /// Whether the class is annotated and [member] returns [generated].
  bool get isCompliant => annotation != null && delegates && !isStaticFromJson;

  /// The finding for [member], or `null` when [isCompliant].
  Finding? get finding =>
      isCompliant ? null : Finding.at(member, message: message);

  /// Why [member] is reported. Only read when it isn't [isCompliant].
  String get message => switch (member) {
    _ when isStaticFromJson =>
      '`$symbol` is a method. Make it a factory constructor, `$factory`.',
    Constructor(isFactory: false) =>
      "`$symbol` is a generative constructor, which can't return the "
          'generated function. $_makeIt a factory constructor, `$factory`.',
    _ when annotation == null && delegates =>
      "`$symbol` delegates to `$generated`, but `${type.name}` isn't "
          'annotated with `@JsonSerializable()`. Annotate it directly, '
          "since vaixell doesn't recognize aliases such as "
          '`@jsonSerializable`. Set `generated-json: off` if you use '
          'another generator, such as freezed.',
    _ when annotation == null =>
      '`$symbol` is written by hand. Annotate `${type.name}` with '
          '`@JsonSerializable()` and delegate to `$generated`. $_converter',
    _ when isTurnedOff =>
      '`$symbol` is written by hand. Remove `$flag: false` from '
          '`@JsonSerializable` and return `$generated($input)` instead. '
          '$_converter',
    _ =>
      '`$symbol` is written by hand. Return `$generated($input)` instead. '
          '$_converter',
  };

  /// The steps that turn a generative `fromJson` into a factory, ending in
  /// "make it".
  String get _makeIt => switch (annotation) {
    null => 'Annotate `${type.name}` with `@JsonSerializable()` and make it',
    _ when isTurnedOff =>
      'Remove `$flag: false` from `@JsonSerializable` and make it',
    _ => 'Make it',
  };

  static final _leadingUnderscores = RegExp('^_*');

  static const _converter =
      'Use a `JsonConverter` for fields that need custom parsing.';
}
