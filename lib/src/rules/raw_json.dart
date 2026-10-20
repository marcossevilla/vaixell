import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:theseus_cli/src/rules/extension_declaration.dart';
import 'package:theseus_cli/src/rules/rule.dart';

/// Reports raw JSON handling outside model classes.
///
/// Flags `jsonDecode` and `jsonEncode` calls, `json.decode` and
/// `json.encode` calls, and `Map<String, dynamic>` types. They are allowed
/// inside `fromJson` constructors and methods, inside `toJson` methods, and
/// in files under a `models` directory. Generated files are never checked.
///
/// Ids use the enclosing declaration and the kind of finding, such as
/// `ApiClient.getUser@decode`, `@encode` or `@map`, so they don't change
/// when code moves or when a finding of another kind is removed.
final class RawJsonRule extends Rule {
  /// Creates the rule.
  const new();

  @override
  String get id => 'raw-json';

  @override
  List<Finding> check(ParsedFile file) {
    final directories = file.path.split('/')..removeLast();
    if (directories.contains('models')) return const [];
    final visitor = _RawJsonVisitor();
    file.unit.accept(visitor);
    return visitor.findings;
  }
}

class _RawJsonVisitor extends RecursiveAstVisitor<void> {
  final List<Finding> findings = [];

  static const String _decodeAdvice =
      'Deserialize JSON in a `fromJson` constructor.';
  static const String _encodeAdvice = 'Serialize JSON in a `toJson` method.';

  /// The kind and advice for each flagged call, by how it's written.
  static const Map<String, (String, String)> _calls = {
    'jsonDecode': ('decode', _decodeAdvice),
    'jsonEncode': ('encode', _encodeAdvice),
    'json.decode': ('decode', _decodeAdvice),
    'json.encode': ('encode', _encodeAdvice),
  };

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (node.name?.lexeme != 'fromJson') {
      super.visitConstructorDeclaration(node);
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final name = node.name.lexeme;
    if (name != 'fromJson' && name != 'toJson') {
      super.visitMethodDeclaration(node);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final method = node.methodName.name;
    final call = switch (node.target) {
      SimpleIdentifier(name: 'json') ||
      PrefixedIdentifier(
        identifier: SimpleIdentifier(name: 'json'),
      ) => 'json.$method',
      null || SimpleIdentifier() => method,
      _ => null,
    };
    if (_calls[call] case (final kind, final advice)) {
      _report(
        node,
        kind,
        '`$call` is not allowed outside model classes. $advice',
      );
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedType(NamedType node) {
    if (_isRawJsonMap(node)) {
      _report(
        node,
        'map',
        '`Map<String, dynamic>` is not allowed outside model classes. '
            'Use a model class with `fromJson` and `toJson`.',
      );
    }
    super.visitNamedType(node);
  }

  bool _isRawJsonMap(NamedType node) =>
      switch (node.typeArguments?.arguments.toList()) {
        [NamedType(name: final key), NamedType(name: final value)] =>
          node.name.lexeme == 'Map' &&
              key.lexeme == 'String' &&
              value.lexeme == 'dynamic',
        _ => false,
      };

  void _report(AstNode node, String kind, String message) {
    findings.add(
      Finding(
        offset: node.offset,
        message: message,
        symbol: '${_symbol(node) ?? ''}@$kind',
      ),
    );
  }

  /// Returns `Container.member`, `member` or `Container` for the
  /// declaration that encloses [node], or `null` at the top of the file.
  String? _symbol(AstNode node) {
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
