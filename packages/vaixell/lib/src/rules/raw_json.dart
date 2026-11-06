import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/rule.dart';

/// Reports raw JSON handling outside model classes.
///
/// Flags `jsonDecode` and `jsonEncode` calls, `json.decode` and
/// `json.encode` calls, and `Map<String, dynamic>` types. They are allowed
/// inside `fromJson` constructors and methods, inside `toJson` methods, and
/// in files under a `models` directory. Generated files are never checked.
///
/// Code at an I/O boundary that hands JSON to a model is also allowed:
///
/// - A decode call or `Map<String, dynamic>` cast that is passed straight
///   to a `fromJson` call, as in
///   `User.fromJson(jsonDecode(body) as Map<String, dynamic>)`.
/// - An encode call whose argument isn't a collection literal, as in
///   `jsonEncode(user)`, which calls `User.toJson`.
///
/// Ids use the enclosing declaration and the kind of finding, such as
/// `ApiClient.getUser@decode`, `@encode` or `@map`, so they don't change
/// when code moves or when a finding of another kind is removed.
final class const RawJsonRule()
    extends Rule
    with ChecksExpressions, ChecksTypeAnnotations, SkipsDirectories {
  /// Creates the rule.
  this;

  /// The advice for each kind of call.
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
    final MethodCall call when !_isInJsonMember(call) => _callFinding(call),
    _ => null,
  };

  @override
  Finding? checkTypeAnnotation(TypeAnnotation type) {
    if (!_isStringDynamicMap(type) ||
        _isInJsonMember(type) ||
        _isPassedToFromJson(type.cast)) {
      return null;
    }
    return Finding.at(
      type,
      qualifier: 'map',
      message:
          '`Map<String, dynamic>` is not allowed outside model classes. '
          'Use a model class with `fromJson` and `toJson`.',
    );
  }

  Finding? _callFinding(MethodCall call) => switch (_kindOf(call)) {
    final kind? when !_handsOffToModel(call, kind) => Finding.at(
      call,
      qualifier: kind,
      message:
          '`${_writtenAs(call)}` is not allowed outside model classes. '
          '${_advice[kind]}',
    ),
    _ => null,
  };

  /// Whether [element] is in a `fromJson` constructor or a `fromJson` or
  /// `toJson` method, where raw JSON belongs.
  bool _isInJsonMember(Enclosed element) => switch (element.member) {
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

  /// `decode` or `encode` for a call to dart:convert's JSON functions.
  String? _kindOf(MethodCall call) => switch (_writtenAs(call)) {
    'jsonDecode' || 'json.decode' => 'decode',
    'jsonEncode' || 'json.encode' => 'encode',
    _ => null,
  };

  /// Whether [call] of [kind] hands JSON straight to or from a model: a
  /// decode passed to `fromJson`, or an encode of something other than a
  /// collection literal, which calls its `toJson`.
  bool _handsOffToModel(MethodCall call, String kind) =>
      switch ((kind, call.arguments)) {
        ('decode', _) => _isPassedToFromJson(call),
        (_, [Argument(name: null, :final value), ...]) =>
          value.unparenthesized is! CollectionLiteral,
        _ => false,
      };

  /// Whether [expression], looking through parentheses and casts, is a
  /// positional argument of a `fromJson` call.
  bool _isPassedToFromJson(Expression? expression) =>
      expression?.isPositionalArgumentOf('fromJson') ?? false;

  bool _isStringDynamicMap(TypeAnnotation type) => switch (type) {
    TypeAnnotation(
      name: 'Map',
      typeArguments: [
        TypeAnnotation(name: 'String'),
        TypeAnnotation(name: 'dynamic'),
      ],
    ) =>
      true,
    _ => false,
  };
}
