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
  List<String> get directories =>
      p.posix.split(p.posix.dirname(path))..remove('.');

  /// The parser doesn't report errors in source order, so they're sorted,
  /// keeping the parser's order among errors at the same offset.
  @override
  late final List<SyntaxError> errors = List.unmodifiable(
    (result.errors.indexed.toList()..sort(_bySourceOrder)).map(
      (entry) => _AstSyntaxError(entry.$2.offset, entry.$2.message),
    ),
  );

  int _bySourceOrder((int, Diagnostic) a, (int, Diagnostic) b) =>
      switch (a.$2.offset.compareTo(b.$2.offset)) {
        0 => a.$1.compareTo(b.$1),
        final order => order,
      };

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

  /// The model of each node, so a node always gives the same object.
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

  /// The model of a method, a constructor or one field.
  Member? member(ast.AstNode node) => switch (node) {
    ast.MethodDeclaration() => _model(node, () => _AstMethod(this, node)),
    ast.ConstructorDeclaration() => _model(
      node,
      () => _AstConstructor(this, node),
    ),
    ast.VariableDeclaration(
      parent: ast.VariableDeclarationList(parent: ast.FieldDeclaration()),
    ) =>
      _model(node, () => _AstField(this, node)),
    _ => null,
  };

  /// The top-level declaration that [node] is in.
  Declaration declarationAround(ast.AstNode node) =>
      declaration(node) ?? declarationAround(node.parent!);

  /// The symbol of [member] in [declaration], or of [declaration] alone.
  String symbolOf(Declaration declaration, Member? member) {
    final container = switch (declaration) {
      TypeDeclaration(:final name) => name ?? '<unnamed>',
      TopLevelFunction(:final name, kind: FunctionKind.setter) => '$name=',
      TopLevelFunction(:final name) || TopLevelVariable(:final name) => name,
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

  List<Parameter> parameters(ast.FormalParameterList? list) => [
    for (final parameter in list?.parameters ?? const <ast.FormalParameter>[])
      _AstParameter(parameter),
  ];
}

final class _AstSyntaxError(
  @override final int offset,
  @override final String message,
) implements SyntaxError {
  @override
  String? get symbol => null;
}

final class _AstImport(final _AstDartFile file, final ast.ImportDirective node)
    implements Import {
  @override
  int get offset => node.importKeyword.offset;

  @override
  String get uri => node.uri.stringValue ?? '';

  @override
  String get symbol => uri;

  @override
  ImportKind get kind => switch (uri) {
    _ when uri.startsWith('dart:') => ImportKind.dart,
    _ when uri.startsWith('package:') => ImportKind.package,
    _ => ImportKind.relative,
  };

  @override
  String? get path => switch ((kind, file.packageName)) {
    (ImportKind.relative, _) => p.posix.normalize(
      p.posix.join(p.posix.dirname(file.path), uri),
    ),
    (ImportKind.package, final name?) when uri.startsWith('package:$name/') =>
      p.posix.join(
        file.packageRoot,
        'lib',
        uri.substring('package:$name/'.length),
      ),
    _ => null,
  };
}
