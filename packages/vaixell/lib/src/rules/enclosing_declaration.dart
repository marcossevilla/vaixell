import 'package:analyzer/dart/ast/ast.dart';
import 'package:vaixell/src/rules/extension_declaration.dart';

/// Names the declaration that encloses an AST node, for use in finding
/// symbols.
class const EnclosingDeclaration() {
  /// Creates the lookup.
  this;

  /// Returns `Container.member`, `member` or `Container` for the
  /// declaration that encloses [node], or `null` at the top of the file.
  ///
  /// Members are methods, constructors (`new` when unnamed), top-level
  /// functions, fields and top-level variables. Local functions and
  /// closures use the member they're in.
  String? symbolOf(AstNode node) {
    String? member;
    String? container;
    for (AstNode? n = node; n != null; n = n.parent) {
      switch (n) {
        case MethodDeclaration(:final name):
          member = name.lexeme;
        case ConstructorDeclaration(:final name):
          member = name?.lexeme ?? 'new';
        case FunctionDeclaration(:final name, parent: CompilationUnit()):
          member = name.lexeme;
        case VariableDeclaration(
          :final name,
          parent: VariableDeclarationList(
            parent: FieldDeclaration() || TopLevelVariableDeclaration(),
          ),
        ):
          member = name.lexeme;
        case VariableDeclarationList(
          :final variables,
          parent: FieldDeclaration() || TopLevelVariableDeclaration(),
        ):
          // A type annotation shared by every variable in the list.
          member ??= variables.first.name.lexeme;
        case ClassDeclaration(:final namePart) ||
            EnumDeclaration(:final namePart) ||
            ExtensionTypeDeclaration(:final namePart):
          container = namePart.typeName.lexeme;
        case MixinDeclaration(:final name):
          container = name.lexeme;
        case ExtensionDeclaration(:final name):
          container = name?.lexeme ?? ExtensionDeclarationRule.unnamed;
      }
    }
    return switch ((container, member)) {
      (final c?, final m?) => '$c.$m',
      (final c?, null) => c,
      (null, final m) => m,
    };
  }
}
