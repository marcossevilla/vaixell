part of '../model.dart';

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

  /// The methods, constructors and fields, in source order, so a primary
  /// constructor, declared in the header, comes first.
  List<Member> get members;

  /// The methods, in source order.
  List<Method> get methods;

  /// The constructors, in source order, primary constructor first.
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
abstract interface class ExtensionDeclaration implements TypeDeclaration {
  /// The type after `on`, which the extension adds members to, or `null`
  /// when the extension has no `on` clause.
  TypeAnnotation? get extendedType;
}

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
