import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/built_in_rule.dart';
import 'package:vaixell/src/rules/rule.dart';

/// Reports top-level functions, getters and setters.
///
/// A top-level `main` function is allowed, because apps need an entrypoint
/// in `lib/main.dart`.
final class const TopLevelFunctionRule()
    extends Rule
    with BuiltInRule, ChecksDeclarations {
  /// Creates the rule.
  this;

  @override
  String get id => 'top-level-function';

  @override
  Finding? checkDeclaration(Declaration declaration) => switch (declaration) {
    TopLevelFunction(name: 'main', kind: FunctionKind.function) => null,
    TopLevelFunction(:final kind, :final name) => Finding.at(
      declaration,
      message:
          'Top-level ${kind.name} `$name` is not allowed. Move it into a '
          'class.',
    ),
    _ => null,
  };
}
