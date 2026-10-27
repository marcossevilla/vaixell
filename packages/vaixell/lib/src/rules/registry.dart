import 'package:vaixell/src/rules/extension_declaration.dart';
import 'package:vaixell/src/rules/parse_error.dart';
import 'package:vaixell/src/rules/raw_json.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/rules/static_method.dart';
import 'package:vaixell/src/rules/top_level_function.dart';
import 'package:vaixell/src/rules/top_level_variable.dart';

/// The closed set of rules that vaixell knows about.
class const RuleRegistry() {
  /// Creates the registry.
  this;

  /// Every rule, in reporting order.
  List<Rule> get all => const [
    ParseErrorRule(),
    TopLevelFunctionRule(),
    TopLevelVariableRule(),
    ExtensionDeclarationRule(),
    StaticMethodRule(),
    RawJsonRule(),
  ];
}
