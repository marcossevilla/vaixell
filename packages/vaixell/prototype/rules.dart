// PROTOTYPE: the declaration rules rewritten on the model in model.dart, for
// discussion on https://github.com/marcossevilla/vaixell/issues/35.
//
// `Rule`, `Finding` and `Severity` keep today's shape (decided in #40 and
// #41). Symbols are written by hand here; where they come from is #37.
// Behavior matches packages/vaixell/lib/src/rules/.

import 'model.dart';

abstract base class Rule {
  const Rule();
  String get id;
  List<Finding> check(DartFile file);
}

final class Finding {
  const Finding({required this.offset, required this.message, this.symbol});
  final int offset;
  final String message;
  final String? symbol;
}

/// Was: a switch over five AST declaration types, plus a ternary on
/// `isGetter`/`isSetter`.
final class StaticMethodRule extends Rule {
  const StaticMethodRule();

  @override
  String get id => 'static-method';

  @override
  List<Finding> check(DartFile file) => [
    for (final type in file.types)
      for (final method in type.methods)
        if (method.isStatic)
          Finding(
            offset: method.offset,
            symbol: _symbol(type, method),
            message:
                'Static ${method.kind.name} `${type.name ?? '<unnamed>'}.'
                '${method.name}` is not allowed. '
                'Use an instance member instead.',
          ),
  ];

  String _symbol(TypeDeclaration type, Method method) =>
      '${type.name ?? '<unnamed>'}.${method.name}'
      '${method.kind == FunctionKind.setter ? '=' : ''}';
}

/// Was: `declaration is FunctionDeclaration` plus token lexemes.
final class TopLevelFunctionRule extends Rule {
  const TopLevelFunctionRule();

  @override
  String get id => 'top-level-function';

  @override
  List<Finding> check(DartFile file) => [
    for (final function in file.functions)
      if (!(function.name == 'main' && function.kind == FunctionKind.function))
        Finding(
          offset: function.offset,
          symbol: function.kind == FunctionKind.setter
              ? '${function.name}='
              : function.name,
          message:
              'Top-level ${function.kind.name} `${function.name}` is not '
              'allowed. Move it into a class.',
        ),
  ];
}

/// Was: nested loop over `TopLevelVariableDeclaration.variables.variables`.
final class TopLevelVariableRule extends Rule {
  const TopLevelVariableRule();

  @override
  String get id => 'top-level-variable';

  @override
  List<Finding> check(DartFile file) => [
    for (final variable in file.variables)
      Finding(
        offset: variable.offset,
        symbol: variable.name,
        message:
            'Top-level ${variable.isConst ? 'constant' : 'variable'} '
            '`${variable.name}` is not allowed. Move it into a class.',
      ),
  ];
}

/// Was: three switch cases over AST nodes and tokens.
final class ExtensionDeclarationRule extends Rule {
  const ExtensionDeclarationRule();

  @override
  String get id => 'extension-declaration';

  @override
  List<Finding> check(DartFile file) => [
    for (final type in file.types)
      if (type.kind == TypeKind.extension || type.kind == TypeKind.extensionType)
        Finding(
          offset: type.offset,
          symbol: type.name ?? '<unnamed>',
          message: switch ((type.kind, type.name)) {
            (TypeKind.extension, null) =>
              'Unnamed extensions are not allowed. Use a class instead.',
            (TypeKind.extension, final name) =>
              'Extension `$name` is not allowed. Use a class instead.',
            (_, final name) =>
              'Extension type `$name` is not allowed. Use a class instead.',
          },
        ),
  ];
}

/// Shows the import model on #32's sketch, with options hard-coded until
/// "Dart API for rule options" (#38) lands.
final class ForbiddenImportRule extends Rule {
  const ForbiddenImportRule();

  @override
  String get id => 'forbidden-import';

  @override
  List<Finding> check(DartFile file) => [
    if (file.packagePath.startsWith('lib/domain/'))
      for (final import in file.imports)
        if (import.uri.startsWith('package:flutter/') ||
            (import.path?.contains('/lib/presentation/') ?? false))
          Finding(
            offset: import.offset,
            symbol: import.uri,
            message: '`${import.uri}` is not allowed in `lib/domain/`.',
          ),
  ];
}

/// The declaration half of generated-json: which members to look at, and
/// the annotation checks. Whether a body "only returns `_$XFromJson(json)`"
/// is expression-level and belongs to #36, so it's a placeholder here.
final class GeneratedJsonDeclarations {
  const GeneratedJsonDeclarations();

  /// `@JsonSerializable`, with or without an import prefix.
  Annotation? jsonSerializable(TypeDeclaration type) => type.annotations
      .where((a) => a.name == 'JsonSerializable')
      .firstOrNull;

  /// Whether `@JsonSerializable(createToJson: false)` turns off [flag].
  bool disables(Annotation annotation, String flag) => annotation.arguments.any(
    (argument) => argument.name == flag && argument.literal == false,
  );

  /// A `toJson` that converts another value, like HydratedBloc's, rather
  /// than the class itself.
  bool convertsValue(Method toJson) => switch (toJson.parameters
      .where((p) => p.isPositional)
      .firstOrNull) {
    final parameter? => !parameter.isFunction,
    null => false,
  };

  /// Members generated-json inspects in a class.
  Iterable<Object> jsonMembers(TypeDeclaration type) => [
    for (final constructor in type.constructors)
      if (constructor.name == 'fromJson' && !constructor.isExternal) constructor,
    for (final method in type.methods)
      if (!method.isAbstract &&
          method.kind == FunctionKind.function &&
          ((method.name == 'fromJson' && method.isStatic) ||
              (method.name == 'toJson' && !convertsValue(method))))
        method,
  ];
}
