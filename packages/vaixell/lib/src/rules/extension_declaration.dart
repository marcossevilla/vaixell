import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/rule.dart';

/// Reports extensions, named or unnamed, and extension types.
final class const ExtensionDeclarationRule()
    extends Rule
    with ChecksDeclarations {
  /// Creates the rule.
  this;

  @override
  String get id => 'extension-declaration';

  @override
  Finding? checkDeclaration(Declaration declaration) => switch (declaration) {
    ExtensionDeclaration(name: null) => Finding.at(
      declaration,
      message: 'Unnamed extensions are not allowed. Use a class instead.',
    ),
    ExtensionDeclaration(:final name?) => Finding.at(
      declaration,
      message: 'Extension `$name` is not allowed. Use a class instead.',
    ),
    ExtensionTypeDeclaration(:final name) => Finding.at(
      declaration,
      message: 'Extension type `$name` is not allowed. Use a class instead.',
    ),
    _ => null,
  };
}
