import 'package:analyzer/dart/ast/ast.dart';
import 'package:vaixell/src/model/model.dart' show AstBridge, DartFile;
import 'package:vaixell/src/rules/enclosing_declaration.dart';
import 'package:vaixell/src/rules/rule.dart';

/// Reports extensions, named or unnamed, and extension types.
final class const ExtensionDeclarationRule() extends Rule {
  /// Creates the rule.
  this;

  @override
  String get id => 'extension-declaration';

  @override
  List<Finding> check(DartFile file) => [
    for (final declaration in const AstBridge().unitOf(file).declarations)
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
          symbol: EnclosingDeclaration.unnamed,
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
