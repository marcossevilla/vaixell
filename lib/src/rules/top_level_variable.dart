import 'package:analyzer/dart/ast/ast.dart';
import 'package:theseus_cli/src/rules/rule.dart';

/// Reports top-level variables, including `final`, `late` and `const` ones.
final class TopLevelVariableRule extends Rule {
  /// Creates the rule.
  const new();

  @override
  String get id => 'top-level-variable';

  @override
  List<Finding> check(ParsedFile file) => [
    for (final declaration in file.unit.declarations)
      if (declaration is TopLevelVariableDeclaration)
        for (final variable in declaration.variables.variables)
          Finding(
            offset: variable.name.offset,
            symbol: variable.name.lexeme,
            message:
                'Top-level '
                '${declaration.variables.isConst ? 'constant' : 'variable'} '
                '`${variable.name.lexeme}` is not allowed. '
                'Move it into a class.',
          ),
  ];
}
