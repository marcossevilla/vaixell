import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/built_in_rule.dart';
import 'package:vaixell/src/rules/rule.dart';

/// Reports top-level variables, including `final`, `late` and `const` ones.
final class const TopLevelVariableRule()
    extends Rule
    with BuiltInRule, ChecksDeclarations {
  /// Creates the rule.
  this;

  @override
  String get id => 'top-level-variable';

  @override
  Finding? checkDeclaration(Declaration declaration) => switch (declaration) {
    TopLevelVariable(:final isConst, :final name) => Finding.at(
      declaration,
      message:
          'Top-level ${isConst ? 'constant' : 'variable'} `$name` is not '
          'allowed. Move it into a class.',
    ),
    _ => null,
  };
}
