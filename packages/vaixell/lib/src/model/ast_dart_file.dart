part of 'model.dart';

/// Builds [DartFile]s from source, without resolving types.
class const DartFileParser() {
  /// Creates the parser.
  this;

  /// Parses [content] as the file at [path], a POSIX path relative to the
  /// repository root.
  ///
  /// The file is in the package at [packageRoot], relative to the repository
  /// root, where `''` is the root itself. [packageName] is the package's
  /// `pubspec.yaml` name, used to resolve imports of the package itself.
  DartFile parse({
    required String path,
    required String content,
    String packageRoot = '',
    String? packageName,
  }) => _AstDartFile(
    path,
    parseString(content: content, path: path, throwIfDiagnostics: false),
    packageRoot,
    packageName,
  );
}

final class _AstDartFile(
  @override final String path,
  final ParseStringResult result,
  final String packageRoot,
  final String? packageName,
) implements DartFile {
  @override
  String get packagePath =>
      packageRoot.isEmpty ? path : p.posix.relative(path, from: packageRoot);

  @override
  late final List<String> directories = List.unmodifiable(
    p.posix.split(p.posix.dirname(path))..remove('.'),
  );

  /// The parser doesn't report errors in source order, so they're sorted,
  /// keeping the parser's order among errors at the same offset.
  @override
  late final List<SyntaxError> errors = List.unmodifiable([
    for (final (_, error)
        in result.errors.indexed.toList()..sort(_bySourceOrder))
      _AstSyntaxError(error.offset, error.message),
  ]);

  int _bySourceOrder((int, Diagnostic) a, (int, Diagnostic) b) {
    final (ia, errorA) = a;
    final (ib, errorB) = b;
    return switch (errorA.offset.compareTo(errorB.offset)) {
      0 => ia.compareTo(ib),
      final order => order,
    };
  }

  @override
  late final List<Import> imports = List.unmodifiable([
    for (final directive in result.unit.directives)
      if (directive is ast.ImportDirective) _AstImport(this, directive),
  ]);

  @override
  late final List<Declaration> declarations = List.unmodifiable([
    for (final node in result.unit.declarations)
      if (node is ast.TopLevelVariableDeclaration)
        for (final variable in node.variables.variables) declaration(variable)!
      else
        ?declaration(node),
  ]);

  late final _AstCollector _collected = _AstCollector(this)
    ..visitCompilationUnit(result.unit);

  @override
  late final List<Expression> expressions = List.unmodifiable(
    _collected.expressions,
  );

  @override
  late final List<TypeAnnotation> typeAnnotations = List.unmodifiable(
    _collected.types,
  );

  /// The model of each node, or of each argument or parameter list, so a
  /// node always gives the same object.
  final Map<ast.AstNode, Object> _models = Map.identity();

  T _model<T extends Object>(ast.AstNode node, T Function() create) =>
      _models.putIfAbsent(node, create) as T;

  /// The model of a top-level declaration, or of one top-level variable.
  Declaration? declaration(ast.AstNode node) => switch (node) {
    ast.ClassDeclaration() => _model(node, () => _AstClass(this, node)),
    ast.MixinDeclaration() => _model(node, () => _AstMixin(this, node)),
    ast.EnumDeclaration() => _model(node, () => _AstEnum(this, node)),
    ast.ExtensionDeclaration() => _model(node, () => _AstExtension(this, node)),
    ast.ExtensionTypeDeclaration() => _model(
      node,
      () => _AstExtensionType(this, node),
    ),
    ast.FunctionDeclaration(parent: ast.CompilationUnit()) => _model(
      node,
      () => _AstTopLevelFunction(this, node),
    ),
    ast.VariableDeclaration(
      parent: ast.VariableDeclarationList(
        parent: ast.TopLevelVariableDeclaration(),
      ),
    ) =>
      _model(node, () => _AstTopLevelVariable(this, node)),
    _ => null,
  };

  /// The model of a method, a constructor or one field. A primary
  /// constructor's body gives the model of its header.
  Member? member(ast.AstNode node) => switch (node) {
    ast.MethodDeclaration() => _model(node, () => _AstMethod(this, node)),
    ast.ConstructorDeclaration() => _model(
      node,
      () => _AstConstructor(this, node),
    ),
    ast.PrimaryConstructorDeclaration() => _model(
      node,
      () => _AstPrimaryConstructor(this, node),
    ),
    ast.PrimaryConstructorBody(:final declaration?) => member(declaration),
    ast.VariableDeclaration(
      parent: ast.VariableDeclarationList(parent: ast.FieldDeclaration()),
    ) =>
      _model(node, () => _AstField(this, node)),
    _ => null,
  };

  Expression expression(ast.Expression node) => _model(
    node,
    () => switch (node) {
      ast.AwaitExpression() => _AstAwait(this, node),
      ast.MethodInvocation() => _AstMethodCall(this, node),
      ast.InstanceCreationExpression() => _AstInstanceCreation(this, node),
      ast.FunctionExpressionInvocation() => _AstFunctionCall(this, node),
      ast.SimpleIdentifier() => _AstIdentifier(this, node),
      ast.PrefixedIdentifier() => _AstPrefixedIdentifier(this, node),
      ast.PropertyAccess() => _AstPropertyAccess(this, node),
      ast.AsExpression() => _AstCast(this, node),
      ast.PostfixExpression(operator: Token(type: TokenType.BANG)) =>
        _AstNullCheck(this, node),
      ast.ThisExpression() => _AstThis(this, node),
      ast.TypedLiteral() => _AstCollectionLiteral(this, node),
      ast.ParenthesizedExpression() => _AstParenthesized(this, node),
      _ => _AstOtherExpression(this, node),
    },
  );

  Expression? expressionOrNull(ast.Expression? node) =>
      node == null ? null : expression(node);

  TypeAnnotation type(ast.TypeAnnotation node) =>
      _model(node, () => _AstTypeAnnotation(this, node));

  /// The declaration and member around [node]. A node in a variable
  /// declaration list, such as a type shared by several variables, belongs
  /// to the first variable.
  ({Declaration? declaration, Member? member}) enclosing(ast.AstNode node) {
    Declaration? declaration;
    Member? member;
    for (ast.AstNode? n = node; n != null; n = n.parent) {
      final subject = switch (n) {
        ast.VariableDeclarationList(:final variables) => variables.first,
        _ => n,
      };
      member ??= this.member(subject);
      declaration ??= this.declaration(subject);
    }
    return (declaration: declaration, member: member);
  }

  /// The symbol of [member] in [declaration], or of [declaration] alone.
  String? symbolOf(Declaration? declaration, Member? member) {
    final container = switch (declaration) {
      TypeDeclaration(:final name) => name ?? '<unnamed>',
      TopLevelFunction(:final name, kind: FunctionKind.setter) => '$name=',
      TopLevelFunction(:final name) || TopLevelVariable(:final name) => name,
      null => null,
    };
    final memberName = switch (member) {
      Method(:final name, kind: FunctionKind.setter) => '$name=',
      Method(:final name) || Field(:final name) => name,
      Constructor(:final name) => name ?? 'new',
      null => null,
    };
    return memberName == null ? container : '$container.$memberName';
  }

  FunctionKind kind({
    required bool isGetter,
    required bool isSetter,
    bool isOperator = false,
  }) => switch ((isGetter, isSetter, isOperator)) {
    (true, _, _) => FunctionKind.getter,
    (_, true, _) => FunctionKind.setter,
    (_, _, true) => FunctionKind.operator,
    _ => FunctionKind.function,
  };

  AccessOperator? accessOperator(Token? token) => switch (token?.type) {
    TokenType.PERIOD => AccessOperator.period,
    TokenType.QUESTION_PERIOD => AccessOperator.questionPeriod,
    TokenType.PERIOD_PERIOD => AccessOperator.cascade,
    TokenType.QUESTION_PERIOD_PERIOD => AccessOperator.questionCascade,
    _ => null,
  };

  /// The arguments in [list], the same list on every call.
  List<Argument> arguments(ast.ArgumentList? list) => switch (list) {
    null => const [],
    _ => _model(
      list,
      () => List<Argument>.unmodifiable([
        for (final argument in list.arguments) _AstArgument(this, argument),
      ]),
    ),
  };

  /// `e` when [body] is `=> e;` or `{ return e; }`, otherwise `null`.
  Expression? returnExpression(ast.FunctionBody body) => switch (body) {
    ast.ExpressionFunctionBody(:final expression) ||
    ast.BlockFunctionBody(
      block: ast.Block(statements: [ast.ReturnStatement(:final expression?)]),
    ) => this.expression(expression),
    _ => null,
  };

  /// The parameters in [list], the same list on every call.
  List<Parameter> parameters(ast.FormalParameterList? list) => switch (list) {
    null => const [],
    _ => _model(
      list,
      () => List<Parameter>.unmodifiable([
        for (final parameter in list.parameters) _AstParameter(parameter),
      ]),
    ),
  };
}

final class _AstSyntaxError(
  @override final int offset,
  @override final String message,
) implements SyntaxError {
  @override
  String? get symbol => null;
}
