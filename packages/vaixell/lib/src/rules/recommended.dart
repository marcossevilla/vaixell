import 'package:vaixell/src/rules/await_receiver.dart';
import 'package:vaixell/src/rules/extension_declaration.dart';
import 'package:vaixell/src/rules/generated_json.dart';
import 'package:vaixell/src/rules/raw_json.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/rules/static_method.dart';
import 'package:vaixell/src/rules/throwaway_instance.dart';
import 'package:vaixell/src/rules/top_level_function.dart';
import 'package:vaixell/src/rules/top_level_variable.dart';

/// The rules that ship with vaixell, which the `recommended` preset enables.
abstract final class Recommended {
  /// vaixell's rules, in reporting order.
  ///
  /// Callers pass a list of rules to vaixell, so they can extend this one, as
  /// in `[...Recommended.rules, myRule]`, or filter it by id. `parse-error`
  /// isn't here: the engine reports it.
  static const List<RuleEntry> rules = [
    TopLevelFunctionRule(),
    TopLevelVariableRule(),
    ExtensionDeclarationRule(),
    StaticMethodRule(),
    ThrowawayInstanceRule(),
    RawJsonRule(),
    GeneratedJsonRule(),
    AwaitReceiverRule(),
  ];
}
