import 'package:analyzer/dart/ast/ast.dart';
import 'package:vaixell/src/rules/extension_declaration.dart';
import 'package:vaixell/src/rules/rule.dart';

/// Reports static methods, getters and setters, public or private, in
/// classes, mixins, enums, extensions and extension types.
///
/// Static fields and factory constructors aren't methods, so they aren't
/// reported.
final class StaticMethodRule extends Rule {
  /// Creates the rule.
  const new();

  @override
  String get id => 'static-method';

  @override
  List<Finding> check(ParsedFile file) => [
    for (final declaration in file.unit.declarations)
      if (_container(declaration) case (final container, final members))
        for (final member in members)
          if (member is MethodDeclaration && member.isStatic)
            _finding(container, member),
  ];

  (String, List<ClassMember>)? _container(CompilationUnitMember node) =>
      switch (node) {
        ClassDeclaration(:final namePart, :final body) => (
          namePart.typeName.lexeme,
          body.members,
        ),
        MixinDeclaration(:final name, :final body) => (
          name.lexeme,
          body.members,
        ),
        EnumDeclaration(:final namePart, :final body) => (
          namePart.typeName.lexeme,
          body.members,
        ),
        ExtensionDeclaration(:final name, :final body) => (
          name?.lexeme ?? ExtensionDeclarationRule.unnamed,
          body.members,
        ),
        ExtensionTypeDeclaration(:final namePart, :final body) => (
          namePart.typeName.lexeme,
          body.members,
        ),
        _ => null,
      };

  Finding _finding(String container, MethodDeclaration method) {
    final name = '$container.${method.name.lexeme}';
    final kind = method.isGetter
        ? 'getter'
        : method.isSetter
        ? 'setter'
        : 'method';
    return Finding(
      offset: method.name.offset,
      symbol: method.isSetter ? '$name=' : name,
      message:
          'Static $kind `$name` is not allowed. '
          'Use an instance member instead.',
    );
  }
}
