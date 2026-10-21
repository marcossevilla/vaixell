import 'package:analyzer/dart/ast/ast.dart';
import 'package:vaixell/src/rules/rule.dart';

/// Reports extensions, named or unnamed, and extension types.
final class ExtensionDeclarationRule extends Rule {
  /// Creates the rule.
  const new();

  /// The symbol used in ids for an extension without a name.
  static const String unnamed = '<unnamed>';

  @override
  String get id => 'extension-declaration';

  @override
  List<Finding> check(ParsedFile file) => [
    for (final declaration in file.unit.declarations)
      ?switch (declaration) {
        ExtensionDeclaration(name: final name?) => Finding(
          offset: name.offset,
          symbol: name.lexeme,
          message:
              'Extension `${name.lexeme}` is not allowed. '
              'Use a class instead.',
        ),
        ExtensionDeclaration(:final extensionKeyword) => Finding(
          offset: extensionKeyword.offset,
          symbol: unnamed,
          message: 'Unnamed extensions are not allowed. Use a class instead.',
        ),
        ExtensionTypeDeclaration(namePart: ClassNamePart(:final typeName)) =>
          Finding(
            offset: typeName.offset,
            symbol: typeName.lexeme,
            message:
                'Extension type `${typeName.lexeme}` is not allowed. '
                'Use a class instead.',
          ),
        _ => null,
      },
  ];
}
