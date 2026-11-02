// PROTOTYPE: rough shape of the declaration-level model, for discussion on
// https://github.com/marcossevilla/vaixell/issues/35. Never merged.
//
// Everything here is a vaixell type. Nothing exposes `package:analyzer`.
// Every element that a rule can report on has an `offset`, which goes
// straight into `Finding(offset: ...)`.

/// A parsed Dart file, as a rule sees it.
abstract interface class DartFile {
  /// The POSIX path of the file, relative to the repository root.
  String get path;

  /// The path relative to the package root, for example `lib/src/a.dart`.
  String get packagePath;

  /// The directories of [path], for example `['lib', 'src', 'models']`.
  List<String> get directories;

  /// Syntax errors, in source order. Empty when the file parses.
  List<SyntaxError> get errors;

  /// The `import` directives, in source order.
  List<Import> get imports;

  /// Classes, mixins, enums, extensions and extension types.
  List<TypeDeclaration> get types;

  /// Top-level functions, getters and setters.
  List<TopLevelFunction> get functions;

  /// Top-level variables and constants, one per declared name.
  List<TopLevelVariable> get variables;
}

/// A syntax error reported by the parser.
abstract interface class SyntaxError {
  int get offset;
  String get message;
}

/// An `import` directive.
abstract interface class Import {
  int get offset;

  /// The URI as written, for example `package:flutter/material.dart`.
  String get uri;

  ImportKind get kind;

  /// The file it points to, relative to the repository root, when that can
  /// be computed without `pub get`: relative imports and imports of the
  /// file's own package. `null` otherwise.
  String? get path;
}

enum ImportKind { dart, package, relative }

/// What kind of type a [TypeDeclaration] is.
enum TypeKind { classType, mixinType, enumType, extension, extensionType }

/// A class, mixin, enum, extension or extension type.
abstract interface class TypeDeclaration {
  TypeKind get kind;

  /// The name, or `null` for an unnamed extension.
  String? get name;

  /// The offset of the name, or of the `extension` keyword when unnamed.
  int get offset;

  List<Annotation> get annotations;

  List<Method> get methods;

  List<Constructor> get constructors;

  List<Field> get fields;
}

/// Whether a function or method is a plain function, a getter or a setter.
enum FunctionKind { function, getter, setter, operator }

/// A method, getter, setter or operator in a [TypeDeclaration].
abstract interface class Method {
  String get name;

  int get offset;

  FunctionKind get kind;

  bool get isStatic;

  bool get isAbstract;

  bool get isExternal;

  List<Parameter> get parameters;

  /// The type it's declared in.
  TypeDeclaration get container;
}

/// A generative or factory constructor.
abstract interface class Constructor {
  /// The name after the dot, or `null` for an unnamed constructor.
  String? get name;

  /// The offset of [name], or of the type name when unnamed.
  int get offset;

  bool get isFactory;

  bool get isExternal;

  List<Parameter> get parameters;

  TypeDeclaration get container;
}

/// A field, one per declared name.
abstract interface class Field {
  String get name;

  int get offset;

  bool get isStatic;

  TypeDeclaration get container;
}

/// A top-level function, getter or setter.
abstract interface class TopLevelFunction {
  String get name;

  int get offset;

  FunctionKind get kind;

  List<Parameter> get parameters;
}

/// A top-level variable, one per declared name.
abstract interface class TopLevelVariable {
  String get name;

  int get offset;

  bool get isConst;

  bool get isFinal;
}

/// A parameter of a function, method or constructor.
abstract interface class Parameter {
  /// The name, or `null` when it has none, as in some function types.
  String? get name;

  bool get isPositional;

  bool get isNamed;

  /// Whether the parameter is itself a function, as in `void f(int g())` or
  /// `Object? Function(T) toJsonT`.
  bool get isFunction;
}

/// An annotation, such as `@JsonSerializable(createToJson: false)`.
abstract interface class Annotation {
  int get offset;

  /// The name without any import prefix, for example `JsonSerializable`.
  String get name;

  /// The import prefix, for example `json` in `@json.JsonSerializable()`.
  String? get prefix;

  /// The arguments, or empty when there are none or no parentheses.
  List<Argument> get arguments;
}

/// An argument of an [Annotation].
abstract interface class Argument {
  /// The name of a named argument, or `null` when positional.
  String? get name;

  /// The value when it's a literal `bool`, `int`, `double`, `String` or
  /// `null`, as a Dart value. [isLiteral] tells `null` apart from a value
  /// that isn't a literal.
  Object? get literal;

  bool get isLiteral;
}
