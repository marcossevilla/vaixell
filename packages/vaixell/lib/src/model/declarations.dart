part of 'model.dart';

/// A top-level declaration that rules see: a type declaration, a function,
/// or one of the names of a top-level variable declaration.
///
/// Its offset is its name's, or its keyword's when it has none.
sealed class Declaration implements Reportable;

/// A declaration with members. Its symbol is its name, or `<unnamed>` for
/// an unnamed extension.
sealed class TypeDeclaration implements Declaration {
  /// The name, `null` only for an unnamed extension.
  String? get name;

  /// The annotations, in source order.
  List<Annotation> get annotations;

  /// The methods, constructors and fields, in source order.
  List<Member> get members;

  /// The methods, in source order.
  List<Method> get methods;

  /// The constructors declared in the body, in source order.
  List<Constructor> get constructors;

  /// The fields, one per declared name, in source order.
  List<Field> get fields;
}

/// A `class`.
abstract interface class ClassDeclaration implements TypeDeclaration {
  @override
  String get name;
}

/// A `mixin`.
abstract interface class MixinDeclaration implements TypeDeclaration {
  @override
  String get name;
}

/// An `enum`.
abstract interface class EnumDeclaration implements TypeDeclaration {
  @override
  String get name;
}

/// An `extension`, which may be unnamed.
abstract interface class ExtensionDeclaration implements TypeDeclaration;

/// An `extension type`.
abstract interface class ExtensionTypeDeclaration implements TypeDeclaration {
  @override
  String get name;
}

/// A top-level function, getter, setter or operator. Its symbol is its
/// name, followed by `=` for a setter.
abstract interface class TopLevelFunction implements Declaration {
  /// The name.
  String get name;

  /// Whether it's a function, a getter, a setter or an operator.
  FunctionKind get kind;
}

/// One name of a top-level variable declaration. Its symbol is its name.
abstract interface class TopLevelVariable implements Declaration {
  /// The name.
  String get name;

  /// Whether it's declared `const`.
  bool get isConst;
}

/// The kinds of [TopLevelFunction]s and [Method]s.
enum FunctionKind {
  /// A plain function or method.
  function,

  /// A getter.
  getter,

  /// A setter.
  setter,

  /// An operator.
  operator;

  /// The word for it as a member: `method`, `getter`, `setter` or
  /// `operator`.
  String get asMember => this == function ? 'method' : name;
}

/// A method, constructor or field of a [TypeDeclaration].
///
/// Its symbol is `Type.member`, `Type.member=` for a setter, or `Type.new`
/// for an unnamed constructor. A member doesn't know its declaration.
sealed class Member implements Reportable;

/// A method, getter, setter or operator.
abstract interface class Method implements Member {
  /// The name.
  String get name;

  /// Whether it's a method, a getter, a setter or an operator.
  FunctionKind get kind;

  /// Whether it's `static`.
  bool get isStatic;

  /// Whether it has no body.
  bool get isAbstract;

  /// Whether it's `external`.
  bool get isExternal;

  /// The parameters, in source order. Empty for a getter.
  List<Parameter> get parameters;
}

/// A constructor. Its offset is its name's, or the type name's or keyword's
/// when it's unnamed.
abstract interface class Constructor implements Member {
  /// The name after the type name, or `null` when unnamed.
  String? get name;

  /// Whether it's a `factory`.
  bool get isFactory;

  /// Whether it's `external`.
  bool get isExternal;

  /// The parameters, in source order.
  List<Parameter> get parameters;
}

/// One name of a field declaration.
abstract interface class Field implements Member {
  /// The name.
  String get name;

  /// Whether it's `static`.
  bool get isStatic;
}

/// A parameter of a [Method] or [Constructor].
abstract interface class Parameter {
  /// The name, `null` only when the source is incomplete.
  String? get name;

  /// Whether it's positional, required or optional.
  bool get isPositional;

  /// Whether it's named.
  bool get isNamed;

  /// Whether it's a function, as in `T Function(Object?) fromJsonT` or
  /// `T fromJsonT(Object?)`.
  bool get isFunction;
}

/// An annotation, `@prefix.name(arguments)`.
///
/// Without types, `@A.named()` reads as `name` `named` with `prefix` `A`.
abstract interface class Annotation {
  /// The last name before the arguments.
  String get name;

  /// The name before the dot, or `null` when there's none.
  String? get prefix;

  /// The arguments, in source order. Empty when there are no parentheses.
  List<Argument> get arguments;
}

/// An argument of an [Annotation].
abstract interface class Argument {
  /// The name, or `null` when positional.
  String? get name;

  /// Whether the value is a `bool`, number, `String` or `null` literal.
  bool get isLiteral;

  /// The value of the literal, when [isLiteral], otherwise `null`.
  Object? get literal;
}
