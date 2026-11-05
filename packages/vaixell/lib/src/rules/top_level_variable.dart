import 'package:analyzer/dart/ast/ast.dart';
import 'package:vaixell/src/model/model.dart' show AstBridge, DartFile;
import 'package:vaixell/src/rules/rule.dart';

/// Reports top-level variables, including `final`, `late` and `const` ones.
final class const TopLevelVariableRule() extends Rule {
  /// Creates the rule.
  this;

  @override
  String get id => 'top-level-variable';

  @override
  List<Finding> check(DartFile file) => [
    for (final declaration in const AstBridge().unitOf(file).declarations)
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
