import 'package:theseus_cli/src/rules/extension_declaration.dart';
import 'package:theseus_cli/src/rules/parse_error.dart';
import 'package:theseus_cli/src/rules/rule.dart';
import 'package:theseus_cli/src/rules/static_method.dart';
import 'package:theseus_cli/src/rules/top_level_function.dart';
import 'package:theseus_cli/src/rules/top_level_variable.dart';

/// The closed set of rules that theseus knows about.
class RuleRegistry {
  /// Creates the registry.
  const new();

  /// Every rule, in reporting order.
  List<Rule> get all => const [
    ParseErrorRule(),
    TopLevelFunctionRule(),
    TopLevelVariableRule(),
    ExtensionDeclarationRule(),
    StaticMethodRule(),
  ];
}
