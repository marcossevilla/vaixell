// PROTOTYPE: wraps the parse-only AST in the model, for
// https://github.com/marcossevilla/vaixell/issues/36. Never merged.
//
// Every model type is a small private class around one AST node. Wrappers
// are created on demand and cached per file, so the same node always gives
// the same object, which keeps `Expression.member` and friends consistent.

part of 'model.dart';

// The `file` and `node` fields declared in primary constructors implement
// the mixins' getters, and `@override` on every parameter adds only noise.
// ignore_for_file: annotate_overrides

/// The model of [file].
DartFile modelOf(ParsedFile file) => _DartFile(file);

final class _DartFile(final ParsedFile parsed) implements DartFile {
  final Map<ast.AstNode, Object> _cache = {};

  late final _Collector _collected = _Collector(this)..collect(parsed.unit);

  @override
  String get path => parsed.path;

  @override
  List<String> get directories => path.split('/')..removeLast();

  @override
  late final List<Declaration> declarations = [
    for (final node in parsed.unit.declarations)
      if (node is ast.TopLevelVariableDeclaration)
        for (final variable in node.variables.variables) declaration(variable)!
      else
        ?declaration(node),
  ];

  @override
  List<Expression> get expressions => _collected.expressions;

  @override
  List<TypeReference> get typeReferences => _collected.types;

  T _wrap<T extends Object>(ast.AstNode node, T Function() create) =>
      _cache.putIfAbsent(node, create) as T;

  // --- Node to model -------------------------------------------------------

  /// The model of a top-level declaration, or of one top-level variable.
  Declaration? declaration(ast.AstNode node) => switch (node) {
    ast.ClassDeclaration() => _wrap(node, () => _Class(this, node)),
    ast.MixinDeclaration() => _wrap(node, () => _Mixin(this, node)),
    ast.EnumDeclaration() => _wrap(node, () => _Enum(this, node)),
    ast.ExtensionDeclaration() => _wrap(node, () => _Extension(this, node)),
    ast.ExtensionTypeDeclaration() => _wrap(
      node,
      () => _ExtensionType(this, node),
    ),
    ast.FunctionDeclaration(parent: ast.CompilationUnit()) => _wrap(
      node,
      () => _TopLevelFunction(node),
    ),
    ast.VariableDeclaration(
      parent: ast.VariableDeclarationList(
        parent: ast.TopLevelVariableDeclaration(),
      ),
    ) =>
      _wrap(node, () => _TopLevelVariable(node)),
    _ => null,
  };

  /// The model of a method, a constructor or one field.
  Member? member(ast.AstNode node) => switch (node) {
    ast.MethodDeclaration() => _wrap(node, () => _Method(this, node)),
    ast.ConstructorDeclaration() => _wrap(node, () => _Constructor(this, node)),
    ast.VariableDeclaration(
      parent: ast.VariableDeclarationList(parent: ast.FieldDeclaration()),
    ) =>
      _wrap(node, () => _Field(node)),
    _ => null,
  };

  Expression expression(ast.Expression node) => _wrap(
    node,
    () => switch (node) {
      ast.AwaitExpression() => _Await(this, node),
      ast.MethodInvocation() => _MethodCall(this, node),
      ast.InstanceCreationExpression() => _InstanceCreation(this, node),
      ast.FunctionExpressionInvocation() => _FunctionCall(this, node),
      ast.SimpleIdentifier() => _Identifier(this, node),
      ast.PrefixedIdentifier() => _PrefixedIdentifier(this, node),
      ast.PropertyAccess() => _PropertyAccess(this, node),
      ast.AsExpression() => _Cast(this, node),
      ast.PostfixExpression(operator: Token(type: TokenType.BANG)) =>
        _NullCheck(this, node),
      ast.ThisExpression() => _This(this, node),
      ast.TypedLiteral() => _CollectionLiteral(this, node),
      ast.ParenthesizedExpression() => _Parenthesized(this, node),
      _ => _OtherExpression(this, node),
    },
  );

  Expression? expressionOrNull(ast.Expression? node) =>
      node == null ? null : expression(node);

  TypeReference type(ast.TypeAnnotation node) =>
      _wrap(node, () => _TypeReference(this, node));

  // --- Shared lookups ------------------------------------------------------

  /// The declaration and member around [node]. A type annotation shared by
  /// several variables belongs to the first.
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

  /// How [node]'s value is used, looking through parentheses and casts.
  Use use(ast.Expression node) {
    ast.AstNode current = node;
    while (_wraps(current.parent, current)) {
      current = current.parent!;
    }
    return switch (current.parent) {
      ast.MethodInvocation(:final ast.Expression? target) ||
      ast.PropertyAccess(:final ast.Expression? target) ||
      ast.IndexExpression(:final ast.Expression? target) ||
      ast.CascadeExpression(
        :final ast.Expression? target,
      ) when target == current => const ReceiverUse(),
      ast.FunctionExpressionInvocation(:final function)
          when function == current =>
        const ReceiverUse(),
      ast.PostfixExpression(operator: Token(type: TokenType.BANG)) =>
        const NullCheckUse(),
      ast.NamedArgument(:final name, parent: final list?) => _argumentOf(
        list,
        name: name.lexeme,
      ),
      final ast.ArgumentList list => _argumentOf(list),
      _ => const OtherUse(),
    };
  }

  /// Whether [parent] only wraps [child] in parentheses or a cast.
  bool _wraps(ast.AstNode? parent, ast.AstNode child) => switch (parent) {
    ast.ParenthesizedExpression() => true,
    ast.AsExpression(:final expression) => expression == child,
    _ => false,
  };

  Use _argumentOf(ast.AstNode list, {String? name}) => switch (list.parent) {
    final ast.Expression call
        when call is ast.MethodInvocation ||
            call is ast.InstanceCreationExpression ||
            call is ast.FunctionExpressionInvocation =>
      ArgumentUse(expression(call) as Call, name: name),
    _ => const OtherUse(),
  };

  Expression? returnExpression(ast.FunctionBody body) => switch (body) {
    ast.ExpressionFunctionBody(:final expression) ||
    ast.BlockFunctionBody(
      block: ast.Block(statements: [ast.ReturnStatement(:final expression?)]),
    ) => this.expression(expression),
    _ => null,
  };

  List<Argument> arguments(ast.ArgumentList? list) => [
    for (final argument in list?.arguments ?? const <ast.Argument>[])
      _Argument(this, argument),
  ];

  List<Parameter> parameters(ast.FormalParameterList? list) => [
    for (final parameter in list?.parameters ?? const <ast.FormalParameter>[])
      _Parameter(parameter),
  ];

  static FunctionKind kind({
    bool isGetter = false,
    bool isSetter = false,
    bool isOperator = false,
  }) => switch ((isGetter, isSetter, isOperator)) {
    (true, _, _) => FunctionKind.getter,
    (_, true, _) => FunctionKind.setter,
    (_, _, true) => FunctionKind.operator,
    _ => FunctionKind.function,
  };

  static AccessOperator? accessOperator(Token? token) => switch (token?.type) {
    TokenType.PERIOD => AccessOperator.period,
    TokenType.QUESTION_PERIOD => AccessOperator.questionPeriod,
    TokenType.PERIOD_PERIOD => AccessOperator.cascade,
    TokenType.QUESTION_PERIOD_PERIOD => AccessOperator.questionCascade,
    _ => null,
  };
}

/// Lists every expression and type annotation in source order.
///
/// Names that are part of a larger node, such as `m` in `a.m()`, aren't
/// expressions of their own, so the visitor skips them.
final class _Collector(final _DartFile file)
    extends GeneralizingAstVisitor<void> {
  final List<Expression> expressions = [];
  final List<TypeReference> types = [];

  void collect(ast.AstNode node) => node.accept(this);

  @override
  void visitExpression(ast.Expression node) {
    expressions.add(file.expression(node));
    super.visitExpression(node);
  }

  @override
  void visitTypeAnnotation(ast.TypeAnnotation node) {
    types.add(file.type(node));
    super.visitTypeAnnotation(node);
  }

  @override
  void visitMethodInvocation(ast.MethodInvocation node) {
    expressions.add(file.expression(node));
    node.target?.accept(this);
    node.typeArguments?.accept(this);
    node.argumentList.accept(this);
  }

  @override
  void visitPrefixedIdentifier(ast.PrefixedIdentifier node) {
    expressions.add(file.expression(node));
    node.prefix.accept(this);
  }

  @override
  void visitPropertyAccess(ast.PropertyAccess node) {
    expressions.add(file.expression(node));
    node.target?.accept(this);
  }

  @override
  void visitAnnotation(ast.Annotation node) {
    node.typeArguments?.accept(this);
    node.arguments?.accept(this);
  }

  @override
  void visitConstructorName(ast.ConstructorName node) => node.type.accept(this);
}

// --- Declarations ------------------------------------------------------------

/// What every type declaration shares: annotations and members.
mixin _Members implements TypeDeclaration {
  _DartFile get file;

  ast.AnnotatedNode get node;

  List<ast.ClassMember> get body;

  @override
  List<Annotation> get annotations => [
    for (final annotation in node.metadata) _Annotation(file, annotation),
  ];

  @override
  List<Method> get methods => [
    for (final m in body.whereType<ast.MethodDeclaration>())
      file.member(m)! as Method,
  ];

  @override
  List<Constructor> get constructors => [
    for (final c in body.whereType<ast.ConstructorDeclaration>())
      file.member(c)! as Constructor,
  ];

  @override
  List<Field> get fields => [
    for (final f in body.whereType<ast.FieldDeclaration>())
      for (final variable in f.fields.variables)
        file.member(variable)! as Field,
  ];
}

final class _Class(final _DartFile file, final ast.ClassDeclaration node)
    with _Members
    implements ClassDeclaration {
  @override
  String get name => node.namePart.typeName.lexeme;

  @override
  int get offset => node.namePart.typeName.offset;

  @override
  List<ast.ClassMember> get body => node.body.members;
}

final class _Mixin(final _DartFile file, final ast.MixinDeclaration node)
    with _Members
    implements MixinDeclaration {
  @override
  String get name => node.name.lexeme;

  @override
  int get offset => node.name.offset;

  @override
  List<ast.ClassMember> get body => node.body.members;
}

final class _Enum(final _DartFile file, final ast.EnumDeclaration node)
    with _Members
    implements EnumDeclaration {
  @override
  String get name => node.namePart.typeName.lexeme;

  @override
  int get offset => node.namePart.typeName.offset;

  @override
  List<ast.ClassMember> get body => node.body.members;
}

final class _Extension(
  final _DartFile file,
  final ast.ExtensionDeclaration node,
) with _Members implements ExtensionDeclaration {
  @override
  String? get name => node.name?.lexeme;

  @override
  int get offset => (node.name ?? node.extensionKeyword).offset;

  @override
  List<ast.ClassMember> get body => node.body.members;
}

final class _ExtensionType(
  final _DartFile file,
  final ast.ExtensionTypeDeclaration node,
) with _Members implements ExtensionTypeDeclaration {
  @override
  String get name => node.namePart.typeName.lexeme;

  @override
  int get offset => node.namePart.typeName.offset;

  @override
  List<ast.ClassMember> get body => node.body.members;
}

final class _TopLevelFunction(final ast.FunctionDeclaration node)
    implements TopLevelFunction {
  @override
  String get name => node.name.lexeme;

  @override
  int get offset => node.name.offset;

  @override
  FunctionKind get kind =>
      _DartFile.kind(isGetter: node.isGetter, isSetter: node.isSetter);
}

final class _TopLevelVariable(final ast.VariableDeclaration node)
    implements TopLevelVariable {
  @override
  String get name => node.name.lexeme;

  @override
  int get offset => node.name.offset;
}

// --- Members -----------------------------------------------------------------

final class _Method(final _DartFile file, final ast.MethodDeclaration node)
    implements Method {
  @override
  String get name => node.name.lexeme;

  @override
  int get offset => node.name.offset;

  @override
  FunctionKind get kind => _DartFile.kind(
    isGetter: node.isGetter,
    isSetter: node.isSetter,
    isOperator: node.isOperator,
  );

  @override
  bool get isStatic => node.isStatic;

  @override
  bool get isAbstract => node.body is ast.EmptyFunctionBody;

  @override
  List<Parameter> get parameters => file.parameters(node.parameters);

  @override
  Expression? get returnExpression => file.returnExpression(node.body);
}

final class _Constructor(
  final _DartFile file,
  final ast.ConstructorDeclaration node,
) implements Constructor {
  @override
  String? get name => node.name?.lexeme;

  @override
  int get offset => node.name?.offset ?? node.offset;

  @override
  bool get isExternal => node.externalKeyword != null;

  @override
  List<Parameter> get parameters => file.parameters(node.parameters);

  @override
  Expression? get returnExpression => file.returnExpression(node.body);
}

final class _Field(final ast.VariableDeclaration node) implements Field {
  @override
  String get name => node.name.lexeme;

  @override
  int get offset => node.name.offset;
}

final class _Parameter(final ast.FormalParameter node) implements Parameter {
  @override
  String? get name => node.name?.lexeme;

  @override
  bool get isPositional => node.isPositional;

  @override
  bool get isFunction =>
      node.functionTypedSuffix != null || node.type is ast.GenericFunctionType;
}

final class _Annotation(final _DartFile file, final ast.Annotation node)
    implements Annotation {
  @override
  String get name => switch (node.name) {
    ast.PrefixedIdentifier(:final identifier) => identifier.name,
    final name => name.name,
  };

  @override
  String? get prefix => switch (node.name) {
    ast.PrefixedIdentifier(:final prefix) => prefix.name,
    _ => null,
  };

  @override
  List<Argument> get arguments => file.arguments(node.arguments);
}

final class _Argument(final _DartFile file, final ast.Argument node)
    implements Argument {
  @override
  String? get name => switch (node) {
    ast.NamedArgument(:final name) => name.lexeme,
    _ => null,
  };

  @override
  Expression get value => file.expression(node.argumentExpression);

  @override
  bool get isLiteral => switch (node.argumentExpression) {
    ast.BooleanLiteral() ||
    ast.IntegerLiteral() ||
    ast.DoubleLiteral() ||
    ast.SimpleStringLiteral() ||
    ast.NullLiteral() => true,
    _ => false,
  };

  @override
  Object? get literal => switch (node.argumentExpression) {
    ast.BooleanLiteral(:final value) => value,
    ast.IntegerLiteral(:final value) => value,
    ast.DoubleLiteral(:final value) => value,
    ast.SimpleStringLiteral(:final value) => value,
    _ => null,
  };
}

// --- Expressions and types ---------------------------------------------------

/// Where an expression or type annotation sits.
mixin _Enclosed implements Enclosed {
  _DartFile get file;

  ast.AstNode get node;

  @override
  int get offset => node.offset;

  @override
  Declaration? get declaration => file.enclosing(node).declaration;

  @override
  Member? get member => file.enclosing(node).member;
}

/// What every expression shares.
mixin _Expression on _Enclosed implements Expression {
  @override
  ast.Expression get node;

  @override
  Use get use => file.use(node);

  @override
  Expression get unparenthesized => file.expression(node.unParenthesized);
}

final class _Await(final _DartFile file, final ast.AwaitExpression node)
    with _Enclosed, _Expression
    implements Await {
  @override
  Expression get operand => file.expression(node.expression);
}

final class _MethodCall(final _DartFile file, final ast.MethodInvocation node)
    with _Enclosed, _Expression
    implements MethodCall {
  @override
  Expression? get target => file.expressionOrNull(node.realTarget);

  @override
  AccessOperator? get operator => _DartFile.accessOperator(node.operator);

  @override
  String get name => node.methodName.name;

  @override
  List<Argument> get arguments => file.arguments(node.argumentList);
}

final class _InstanceCreation(
  final _DartFile file,
  final ast.InstanceCreationExpression node,
) with _Enclosed, _Expression implements InstanceCreation {
  /// Without types, `new User.fromJson()` parses `User` as an import prefix
  /// and `fromJson` as the type, so the type's name can be the last name.
  @override
  String get name =>
      node.constructorName.name?.name ?? node.constructorName.type.name.lexeme;

  @override
  List<Argument> get arguments => file.arguments(node.argumentList);
}

final class _FunctionCall(
  final _DartFile file,
  final ast.FunctionExpressionInvocation node,
) with _Enclosed, _Expression implements FunctionCall {
  @override
  Expression get callee => file.expression(node.function);

  @override
  List<Argument> get arguments => file.arguments(node.argumentList);
}

/// `name`.
final class _Identifier(final _DartFile file, final ast.SimpleIdentifier node)
    with _Enclosed, _Expression
    implements Reference {
  @override
  Expression? get target => null;

  @override
  AccessOperator? get operator => null;

  @override
  String get name => node.name;
}

/// `prefix.name`, which without types may be a property or an import prefix.
final class _PrefixedIdentifier(
  final _DartFile file,
  final ast.PrefixedIdentifier node,
) with _Enclosed, _Expression implements Reference {
  @override
  Expression get target => file.expression(node.prefix);

  @override
  AccessOperator get operator => AccessOperator.period;

  @override
  String get name => node.identifier.name;
}

/// `target.name`, `target?.name` or `..name`.
final class _PropertyAccess(final _DartFile file, final ast.PropertyAccess node)
    with _Enclosed, _Expression
    implements Reference {
  @override
  Expression get target => file.expression(node.realTarget);

  @override
  AccessOperator? get operator => _DartFile.accessOperator(node.operator);

  @override
  String get name => node.propertyName.name;
}

final class _Cast(final _DartFile file, final ast.AsExpression node)
    with _Enclosed, _Expression
    implements Cast {
  @override
  Expression get operand => file.expression(node.expression);

  @override
  TypeReference get type => file.type(node.type);
}

final class _NullCheck(final _DartFile file, final ast.PostfixExpression node)
    with _Enclosed, _Expression
    implements NullCheck {
  @override
  Expression get operand => file.expression(node.operand);
}

final class _This(final _DartFile file, final ast.ThisExpression node)
    with _Enclosed, _Expression
    implements This;

final class _CollectionLiteral(
  final _DartFile file,
  final ast.TypedLiteral node,
) with _Enclosed, _Expression implements CollectionLiteral;

final class _Parenthesized(
  final _DartFile file,
  final ast.ParenthesizedExpression node,
) with _Enclosed, _Expression implements Parenthesized {
  @override
  Expression get expression => file.expression(node.expression);
}

final class _OtherExpression(final _DartFile file, final ast.Expression node)
    with _Enclosed, _Expression
    implements OtherExpression;

final class _TypeReference(final _DartFile file, final ast.TypeAnnotation node)
    with _Enclosed
    implements TypeReference {
  @override
  String? get name => switch (node) {
    ast.NamedType(:final name) => name.lexeme,
    _ => null,
  };

  @override
  String? get prefix => switch (node) {
    ast.NamedType(:final importPrefix?) => importPrefix.name.lexeme,
    _ => null,
  };

  @override
  List<TypeReference> get typeArguments => switch (node) {
    ast.NamedType(:final typeArguments?) => [
      for (final argument in typeArguments.arguments) file.type(argument),
    ],
    _ => const [],
  };

  @override
  Cast? get cast => switch (node.parent) {
    final ast.AsExpression cast => file.expression(cast) as Cast,
    _ => null,
  };
}
