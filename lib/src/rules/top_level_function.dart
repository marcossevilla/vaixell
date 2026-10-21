import 'package:analyzer/dart/ast/ast.dart';
import 'package:vaixell/src/rules/rule.dart';

/// Reports top-level functions, getters and setters.
///
/// A top-level `main` function is allowed, because apps need an entrypoint
/// in `lib/main.dart`.
final class const TopLevelFunctionRule() extends Rule {
  /// Creates the rule.
  this;

  @override
  String get id => 'top-level-function';

  @override
  List<Finding> check(ParsedFile file) => [
    for (final declaration in file.unit.declarations)
      if (declaration is FunctionDeclaration && !_isMain(declaration))
        _finding(declaration),
  ];

  bool _isMain(FunctionDeclaration declaration) =>
      declaration.name.lexeme == 'main' &&
      !declaration.isGetter &&
      !declaration.isSetter;

  Finding _finding(FunctionDeclaration declaration) {
    final name = declaration.name.lexeme;
    final kind = declaration.isGetter
        ? 'getter'
        : declaration.isSetter
        ? 'setter'
        : 'function';
    return Finding(
      offset: declaration.name.offset,
      symbol: declaration.isSetter ? '$name=' : name,
      message: 'Top-level $kind `$name` is not allowed. Move it into a class.',
    );
  }
}
