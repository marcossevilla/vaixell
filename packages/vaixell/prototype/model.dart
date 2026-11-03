// PROTOTYPE: the expression-level model, for discussion on
// https://github.com/marcossevilla/vaixell/issues/36. Never merged.
//
// The declaration part restates what #35 approved, trimmed to what the rules
// in rules.dart touch (imports, errors and `packagePath` are left out). Lines
// marked NEW are what this ticket adds.
//
// No public type or signature mentions `package:analyzer`. The adapter.dart
// part builds the model from the parse-only AST, and prototype/test re-runs
// today's rule tests against the rules in rules.dart.

// ignore_for_file: public_member_api_docs

import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vaixell/src/rules/rule.dart' show ParsedFile;

part 'adapter.dart';

/// A parsed Dart file, as a rule sees it.
abstract interface class DartFile {
  /// The POSIX path of the file, relative to the repository root.
  String get path;

  /// The directories of [path], for example `['lib', 'src', 'models']`.
  List<String> get directories;

  /// The top-level declarations, in source order.
  List<Declaration> get declarations;

  /// NEW: every expression in the file, at any depth, in source order,
  /// including those in annotations, initializers and default values.
  List<Expression> get expressions;

  /// NEW: every type annotation in the file, at any depth, in source order,
  /// including type arguments, as in both types of
  /// `List<Map<String, dynamic>>`.
  List<TypeReference> get typeReferences;
}

// --- Declarations (#35) ----------------------------------------------------

sealed class Declaration {
  int get offset;
}

/// A declaration that has members.
sealed class TypeDeclaration implements Declaration {
  /// The name, or `null` for an unnamed extension.
  String? get name;

  List<Annotation> get annotations;

  List<Method> get methods;

  List<Constructor> get constructors;

  List<Field> get fields;
}

abstract interface class ClassDeclaration implements TypeDeclaration {}

abstract interface class MixinDeclaration implements TypeDeclaration {}

abstract interface class EnumDeclaration implements TypeDeclaration {}

abstract interface class ExtensionDeclaration implements TypeDeclaration {}

abstract interface class ExtensionTypeDeclaration implements TypeDeclaration {}

abstract interface class TopLevelFunction implements Declaration {
  String get name;

  FunctionKind get kind;

  List<Parameter> get parameters;
}

/// One per declared name.
abstract interface class TopLevelVariable implements Declaration {
  String get name;

  bool get isConst;
}

enum FunctionKind { function, getter, setter, operator }

/// NEW: groups the members of a [TypeDeclaration], so an [Expression] can say
/// which one it's in.
sealed class Member {
  int get offset;
}

abstract interface class Method implements Member {
  String get name;

  FunctionKind get kind;

  bool get isStatic;

  /// Whether it has no body.
  bool get isAbstract;

  bool get isExternal;

  List<Parameter> get parameters;

  /// NEW: see [Constructor.returnExpression].
  Expression? get returnExpression;
}

abstract interface class Constructor implements Member {
  /// The name after the dot, or `null` when unnamed.
  String? get name;

  bool get isFactory;

  bool get isExternal;

  List<Parameter> get parameters;

  /// NEW: `e` when the body is `=> e;` or `{ return e; }` with nothing else
  /// in the block, or `null` otherwise.
  Expression? get returnExpression;
}

/// One per declared name.
abstract interface class Field implements Member {
  String get name;

  bool get isStatic;
}

abstract interface class Parameter {
  String? get name;

  bool get isPositional;

  bool get isNamed;

  bool get isFunction;
}

abstract interface class Annotation {
  int get offset;

  String get name;

  String? get prefix;

  List<Argument> get arguments;
}

/// An argument of an [Annotation] or, NEW, of a [Call].
abstract interface class Argument {
  /// The name of a named argument, or `null` when positional.
  String? get name;

  /// The value when it's a literal `bool`, `int`, `double`, `String` or
  /// `null`. [isLiteral] tells `null` apart from a value that isn't one.
  Object? get literal;

  bool get isLiteral;

  /// NEW: the argument's expression.
  Expression get value;
}

// --- Expressions (NEW) -------------------------------------------------------

/// An expression. Only the forms a rule needs to tell apart get their own
/// type. Everything else is an [OtherExpression], whose subexpressions are
/// still in [DartFile.expressions].
sealed class Expression {
  /// The offset of the first token. For an [Await], the `await` keyword.
  int get offset;

  /// How the value is used, looking through parentheses and `as` casts.
  Use get use;

  /// The top-level declaration it's in, or `null` in a library directive's
  /// annotation.
  Declaration? get declaration;

  /// The member of [declaration] it's in, or `null` when it's in the
  /// declaration itself, as in an annotation or an enum value.
  Member? get member;
}

/// `await operand`.
abstract interface class Await implements Expression {
  Expression get operand;
}

/// A call with an argument list.
sealed class Call implements Expression {
  List<Argument> get arguments;
}

/// `name(…)`, `target.name(…)`, `target?.name(…)` or a cascade section
/// `..name(…)`.
///
/// Without types, `User.fromJson(…)` and `User(…)` are method calls too.
abstract interface class MethodCall implements Call {
  /// What it's called on, or `null` for `name(…)`. In a cascade section,
  /// the cascade's target.
  Expression? get target;

  /// How [target] is accessed, or `null` when there's no target.
  AccessOperator? get operator;

  String get name;
}

/// `new …(…)` or `const …(…)`.
abstract interface class InstanceCreation implements Call {
  /// The last identifier before the arguments: `fromJson` in
  /// `new User.fromJson(…)` and `new api.User.fromJson(…)`, `User` in
  /// `const User()`.
  String get name;
}

/// A call of any other expression, as in `(await f)()` or `f()()`.
abstract interface class FunctionCall implements Call {
  Expression get callee;
}

/// `name`, `target.name`, `target?.name` or a cascade section `..name`.
abstract interface class Reference implements Expression {
  /// What it's read from, or `null` for `name`. In a cascade section, the
  /// cascade's target.
  Expression? get target;

  /// How [target] is accessed, or `null` when there's no target.
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
abstract interface class This implements Expression {}

/// A list, set or map literal.
abstract interface class CollectionLiteral implements Expression {}

/// `(expression)`.
abstract interface class Parenthesized implements Expression {
  Expression get expression;
}

/// Any other expression.
abstract interface class OtherExpression implements Expression {}

/// How an expression's value is used. [Expression.use] looks through
/// parentheses and `as` casts first, so `((await f) as T).x` is a
/// [ReceiverUse] of the `await`.
sealed class Use {
  const Use();
}

/// The target of `.`, `?.`, `[]`, `?[]`, `..` or `?..`, or the callee of
/// `()`.
final class ReceiverUse extends Use {
  const ReceiverUse();
}

/// The operand of `!`.
final class NullCheckUse extends Use {
  const NullCheckUse();
}

/// An argument of [call].
final class ArgumentUse extends Use {
  const ArgumentUse(this.call, {this.name});

  final Call call;

  /// The name of a named argument, or `null` when positional.
  final String? name;
}

/// Anything else.
final class OtherUse extends Use {
  const OtherUse();
}

/// NEW: a type annotation, such as `Map<String, dynamic>`.
abstract interface class TypeReference {
  int get offset;

  /// The name without any import prefix, or `null` for a function or record
  /// type.
  String? get name;

  String? get prefix;

  /// The type arguments, or empty when there are none.
  List<TypeReference> get typeArguments;

  /// See [Expression.declaration]. A type annotation shared by several
  /// variables, as in `Map<String, dynamic> a, b;`, belongs to the first.
  Declaration? get declaration;

  /// See [Expression.member].
  Member? get member;
}
