part of '../model.dart';

/// A method, constructor or field of a [TypeDeclaration].
///
/// Its symbol is `Type.member`, `Type.member=` for a setter, or `Type.new`
/// for an unnamed constructor. A member doesn't know its declaration.
sealed class Member implements Reportable {
  /// The name, `null` only for an unnamed constructor.
  String? get name;
}

/// A [Method] or [Constructor]: a member with parameters and a body.
sealed class FunctionMember implements Member {
  /// Whether it's `external`.
  bool get isExternal;

  /// The parameters, in source order. Empty for a getter.
  List<Parameter> get parameters;

  /// `e` when the body is `=> e;` or `{ return e; }`, otherwise `null`.
  Expression? get returnExpression;
}

/// A method, getter, setter or operator.
abstract interface class Method implements FunctionMember {
  /// The name.
  @override
  String get name;

  /// Whether it's a method, a getter, a setter or an operator.
  FunctionKind get kind;

  /// Whether it's `static`.
  bool get isStatic;

  /// Whether it has no body.
  bool get isAbstract;
}

/// A constructor, in the body or, as a primary constructor, in the header,
/// as in `class const User.fromJson(final Map<String, dynamic> json)`.
///
/// Its offset is its name's, or the type name's or keyword's when it's
/// unnamed. Expressions in a primary constructor's header and in its
/// `this : …;` body are in it.
abstract interface class Constructor implements FunctionMember {
  /// The name after the type name, or `null` when unnamed.
  @override
  String? get name;

  /// Whether it's a `factory`.
  bool get isFactory;
}

/// One name of a field declaration.
abstract interface class Field implements Member {
  /// The name.
  @override
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
