// PROTOTYPE: the expression-level model, for discussion on
// https://github.com/marcossevilla/vaixell/issues/36. Never merged.
//
// This is everything a rule author sees. The declaration part restates what
// #35 approved, trimmed to what rules.dart uses. NEW marks what #36 adds.
//
// No public type mentions `package:analyzer`. The adapter.dart part wraps
// the parse-only AST in private classes. It's a part because the types here
// are sealed, so only this library can implement them.

import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/rules/rule.dart' show ParsedFile;

part 'adapter.dart';

/// A parsed Dart file.
abstract interface class DartFile {
  /// The POSIX path, relative to the repository root.
  String get path;

  /// The path relative to the package root, for example `lib/src/a.dart`.
  String get packagePath;

  /// The directories of [path], for example `['lib', 'src', 'models']`.
  List<String> get directories;

  /// Syntax errors, in source order. Empty when the file parses.
  List<SyntaxError> get errors;

  /// The `import` directives, in source order.
  List<Import> get imports;

  /// The top-level declarations, in source order.
  List<Declaration> get declarations;

  /// NEW: every expression, at any depth, in source order.
  List<Expression> get expressions;

  /// NEW: every type annotation, at any depth, in source order. Both types
  /// in `List<Map<String, dynamic>>` are in it.
  List<TypeReference> get typeReferences;
}

// --- Reportable elements ----------------------------------------------------

/// Something a finding can point at.
sealed class Located {
  int get offset;

  /// NEW (#37): what violation ids call it: `Container.member`, `member` or
  /// `Container`, or `null` when it has no name. Setters end in `=`,
  /// unnamed constructors are `new` and unnamed extensions are `<unnamed>`.
  String? get symbol;
}

/// A syntax error reported by the parser.
abstract interface class SyntaxError implements Located {
  String get message;
}

/// An `import` directive, as decided in #44. Its offset is the `import`
/// keyword's and its symbol is [uri].
abstract interface class Import implements Located {
  /// The URI as written, for example `package:flutter/material.dart`.
  String get uri;

  ImportKind get kind;

  /// The file it imports, relative to the repository root, for relative
  /// imports and imports of the file's own package. `null` otherwise.
  String? get path;
}

enum ImportKind { dart, package, relative }

// --- Declarations (#35) ----------------------------------------------------

sealed class Declaration implements Located;

/// A declaration with members.
sealed class TypeDeclaration implements Declaration {
  /// `null` only for an unnamed extension.
  String? get name;

  List<Annotation> get annotations;

  /// NEW: methods, constructors and fields, in source order.
  List<Member> get members;

  List<Method> get methods;

  List<Constructor> get constructors;

  List<Field> get fields;
}

abstract interface class ClassDeclaration implements TypeDeclaration {
  @override
  String get name;
}

abstract interface class MixinDeclaration implements TypeDeclaration {
  @override
  String get name;
}

abstract interface class EnumDeclaration implements TypeDeclaration {
  @override
  String get name;
}

abstract interface class ExtensionDeclaration implements TypeDeclaration;

abstract interface class ExtensionTypeDeclaration implements TypeDeclaration {
  @override
  String get name;
}

abstract interface class TopLevelFunction implements Declaration {
  String get name;

  FunctionKind get kind;
}

/// One per declared name.
abstract interface class TopLevelVariable implements Declaration {
  String get name;

  bool get isConst;
}

enum FunctionKind { function, getter, setter, operator }

/// NEW: a method, constructor or field of a [TypeDeclaration].
sealed class Member implements Located;

abstract interface class Method implements Member {
  String get name;

  FunctionKind get kind;

  bool get isStatic;

  /// Whether it has no body.
  bool get isAbstract;

  List<Parameter> get parameters;

  /// NEW: `e` when the body is `=> e;` or `{ return e; }`, else `null`.
  Expression? get returnExpression;
}

abstract interface class Constructor implements Member {
  /// The name after the dot, or `null` when unnamed.
  String? get name;

  bool get isExternal;

  List<Parameter> get parameters;

  /// NEW: `e` when the body is `=> e;` or `{ return e; }`, else `null`.
  Expression? get returnExpression;
}

/// One per declared name.
abstract interface class Field implements Member {
  String get name;
}

abstract interface class Parameter {
  String? get name;

  bool get isPositional;

  /// Whether it's a function, as in `T Function(Object?) fromJsonT`.
  bool get isFunction;
}

/// `@prefix.name(arguments)`.
abstract interface class Annotation {
  String get name;

  String? get prefix;

  List<Argument> get arguments;
}

/// An argument of an [Annotation] or, NEW, a [Call].
abstract interface class Argument {
  /// `null` when positional.
  String? get name;

  /// NEW.
  Expression get value;

  /// The value of a `bool`, number, `String` or `null` literal.
  Object? get literal;

  /// Whether [value] is one of the literals [literal] covers.
  bool get isLiteral;
}

// --- Where code sits (NEW) ---------------------------------------------------

/// An expression or type annotation, and the declaration it's written in.
/// Its [symbol] is the one of where it is.
sealed class Enclosed implements Located {
  /// The top-level declaration it's in. `null` in a library directive's
  /// annotation, a top-level variable declaration's annotation, or a
  /// typedef, which #35 doesn't model.
  Declaration? get declaration;

  /// The member of [declaration] it's in, or `null` when it's in the
  /// declaration itself, such as its annotations or an enum value.
  Member? get member;
}

/// The symbol of [member] in [declaration], or of [declaration] alone.
String? _symbolOf(Declaration? declaration, Member? member) {
  final container = switch (declaration) {
    TypeDeclaration(:final name) => name ?? '<unnamed>',
    TopLevelFunction(:final name, kind: FunctionKind.setter) => '$name=',
    TopLevelFunction(:final name) || TopLevelVariable(:final name) => name,
    null => null,
  };
  final memberName = switch (member) {
    Method(:final name, kind: FunctionKind.setter) => '$name=',
    Method(:final name) || Field(:final name) => name,
    Constructor(:final name) => name ?? 'new',
    null => null,
  };
  return memberName == null ? container : '$container.$memberName';
}

// --- Expressions (NEW) -------------------------------------------------------

/// An expression. Forms that rules tell apart get their own type. The rest
/// are [OtherExpression]s, whose parts are still in [DartFile.expressions].
sealed class Expression implements Enclosed {
  /// How the value is used, looking through parentheses and `as` casts.
  Use get use;

  /// This expression without any parentheses around it.
  Expression get unparenthesized;
}

/// `await operand`.
abstract interface class Await implements Expression {
  Expression get operand;
}

/// Something called with an argument list.
sealed class Call implements Expression {
  List<Argument> get arguments;
}

/// `name(…)`, `target.name(…)`, `target?.name(…)` or `..name(…)`.
///
/// Without types, `User(…)` and `User.fromJson(…)` are method calls too.
abstract interface class MethodCall implements Call {
  /// `null` for `name(…)`. In a cascade, the cascade's target.
  Expression? get target;

  /// `null` when there's no [target].
  AccessOperator? get operator;

  String get name;
}

/// `new …(…)` or `const …(…)`.
abstract interface class InstanceCreation implements Call {
  /// The last name before the arguments: `fromJson` in
  /// `new User.fromJson(…)`, `User` in `const User()`.
  String get name;
}

/// Any other expression called, as in `(await f)()`.
abstract interface class FunctionCall implements Call {
  Expression get callee;
}

/// `name`, `target.name`, `target?.name` or `..name`.
abstract interface class Reference implements Expression {
  /// `null` for `name`. In a cascade, the cascade's target.
  Expression? get target;

  /// `null` when there's no [target].
  AccessOperator? get operator;

  String get name;
}

/// `.`, `?.`, `..` or `?..`.
enum AccessOperator { period, questionPeriod, cascade, questionCascade }

/// `operand as type`.
abstract interface class Cast implements Expression {
  Expression get operand;

  TypeReference get type;
}

/// `operand!`.
abstract interface class NullCheck implements Expression {
  Expression get operand;
}

/// `this`.
abstract interface class This implements Expression;

/// A list, set or map literal.
abstract interface class CollectionLiteral implements Expression;

/// `(expression)`.
abstract interface class Parenthesized implements Expression {
  Expression get expression;
}

abstract interface class OtherExpression implements Expression;

/// How a value is used. See [Expression.use].
sealed class const Use();

/// The target of `.`, `?.`, `[]`, `?[]`, `..` or `?..`, or the callee of
/// `()`.
final class const ReceiverUse() extends Use;

/// The operand of `!`.
final class const NullCheckUse() extends Use;

/// An argument of [call]. [name] is `null` when positional.
final class const ArgumentUse(final Call call, {final String? name})
    extends Use;

final class const OtherUse() extends Use;

// --- Types (NEW) -------------------------------------------------------------

/// A type annotation, such as `Map<String, dynamic>`.
///
/// A type annotation shared by several variables, as in
/// `Map<String, dynamic> a, b;`, is enclosed by the first.
abstract interface class TypeReference implements Enclosed {
  /// `null` for a function or record type.
  String? get name;

  String? get prefix;

  List<TypeReference> get typeArguments;

  /// The cast this is the type of, as in `x as Map<String, dynamic>`.
  Cast? get cast;
}
