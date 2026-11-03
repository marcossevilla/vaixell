// PROTOTYPE: builds the model in model.dart from the parse-only AST, for
// https://github.com/marcossevilla/vaixell/issues/36. Never merged.
//
// Only this part uses `package:analyzer`, and only in private classes. It
// shows the model can be built from what the engine already parses.

// It's a part of model.dart because the model's types are sealed. In the
// real thing, the model library would be built the same way, with every
// analyzer type private.

part of 'model.dart';

/// Builds the model of [file].
DartFile modelOf(ParsedFile file) => _Builder(file).build();

class _Builder {
  _Builder(this.file);

  final ParsedFile file;
  final Map<ast.AstNode, Declaration> _declarations = {};
  final Map<ast.AstNode, Member> _members = {};
  final Map<ast.Expression, Expression> _expressions = {};
  final Map<ast.TypeAnnotation, TypeReference> _types = {};

  DartFile build() {
    final declarations = [
      for (final node in file.unit.declarations) ..._declaration(node),
    ];
    final collector = _Collector(this);
    file.unit.accept(collector);
    return _DartFile(
      path: file.path,
      directories: file.path.split('/')..removeLast(),
      declarations: declarations,
      expressions: collector.expressions,
      typeReferences: collector.types,
    );
  }

  // --- Declarations --------------------------------------------------------

  List<Declaration> _declaration(ast.CompilationUnitMember node) {
    Declaration register(Declaration d) => _declarations[node] = d;
    return switch (node) {
      ast.ClassDeclaration() => [
        register(
          _Type.of(
            this,
            _Class.new,
            node.namePart.typeName.lexeme,
            node.namePart.typeName.offset,
            node.metadata,
            node.body.members,
          ),
        ),
      ],
      ast.MixinDeclaration() => [
        register(
          _Type.of(
            this,
            _Mixin.new,
            node.name.lexeme,
            node.name.offset,
            node.metadata,
            node.body.members,
          ),
        ),
      ],
      ast.EnumDeclaration() => [
        register(
          _Type.of(
            this,
            _Enum.new,
            node.namePart.typeName.lexeme,
            node.namePart.typeName.offset,
            node.metadata,
            node.body.members,
          ),
        ),
      ],
      ast.ExtensionDeclaration() => [
        register(
          _Type.of(
            this,
            _Extension.new,
            node.name?.lexeme,
            (node.name ?? node.extensionKeyword).offset,
            node.metadata,
            node.body.members,
          ),
        ),
      ],
      ast.ExtensionTypeDeclaration() => [
        register(
          _Type.of(
            this,
            _ExtensionType.new,
            node.namePart.typeName.lexeme,
            node.namePart.typeName.offset,
            node.metadata,
            node.body.members,
          ),
        ),
      ],
      ast.FunctionDeclaration() => [
        register(
          _TopLevelFunction(
            name: node.name.lexeme,
            offset: node.name.offset,
            kind: _kind(
              isGetter: node.isGetter,
              isSetter: node.isSetter,
              isOperator: false,
            ),
            parameters: _parameters(node.functionExpression.parameters),
          ),
        ),
      ],
      ast.TopLevelVariableDeclaration() => [
        for (final variable in node.variables.variables)
          _declarations[variable] = _TopLevelVariable(
            name: variable.name.lexeme,
            offset: variable.name.offset,
            isConst: node.variables.isConst,
          ),
      ],
      _ => const [],
    };
  }

  FunctionKind _kind({
    required bool isGetter,
    required bool isSetter,
    required bool isOperator,
  }) => isGetter
      ? FunctionKind.getter
      : isSetter
      ? FunctionKind.setter
      : isOperator
      ? FunctionKind.operator
      : FunctionKind.function;

  List<Parameter> _parameters(ast.FormalParameterList? list) => [
    for (final p in list?.parameters ?? const <ast.FormalParameter>[])
      _Parameter(
        name: p.name?.lexeme,
        isPositional: p.isPositional,
        isNamed: p.isNamed,
        isFunction:
            p.functionTypedSuffix != null || p.type is ast.GenericFunctionType,
      ),
  ];

  List<Annotation> _annotations(List<ast.Annotation> metadata) => [
    for (final a in metadata)
      _Annotation(
        offset: a.offset,
        name: switch (a.name) {
          ast.PrefixedIdentifier(:final identifier) => identifier.name,
          final name => name.name,
        },
        prefix: switch (a.name) {
          ast.PrefixedIdentifier(:final prefix) => prefix.name,
          _ => null,
        },
        arguments: _arguments(a.arguments),
      ),
  ];

  List<Argument> _arguments(ast.ArgumentList? list) => [
    for (final argument in list?.arguments ?? const <ast.Argument>[])
      _Argument(this, switch (argument) {
        ast.NamedArgument(:final name) => name.lexeme,
        _ => null,
      }, argument.argumentExpression),
  ];

  Expression? _returned(ast.FunctionBody body) => switch (body) {
    ast.ExpressionFunctionBody(expression: final e) ||
    ast.BlockFunctionBody(
      block: ast.Block(statements: [ast.ReturnStatement(expression: final e?)]),
    ) => expression(e),
    _ => null,
  };

  // --- Expressions ---------------------------------------------------------

  Expression expression(ast.Expression node) =>
      _expressions[node] ??= _newExpression(node);

  Expression _newExpression(ast.Expression node) {
    final site = _Site(this, node);
    return switch (node) {
      ast.AwaitExpression() => _Await(site, node.awaitKeyword.offset, node),
      ast.MethodInvocation() => _MethodCall(site, node),
      ast.InstanceCreationExpression(:final constructorName) =>
        _InstanceCreation(
          site,
          node,
          constructorName.name?.name ?? constructorName.type.name.lexeme,
        ),
      ast.FunctionExpressionInvocation() => _FunctionCall(site, node),
      ast.SimpleIdentifier(:final name) => _Reference(site, null, null, name),
      ast.PrefixedIdentifier(:final prefix, :final identifier) => _Reference(
        site,
        prefix,
        AccessOperator.period,
        identifier.name,
      ),
      ast.PropertyAccess(
        :final realTarget,
        :final operator,
        :final propertyName,
      ) =>
        _Reference(site, realTarget, _operator(operator), propertyName.name),
      ast.AsExpression() => _Cast(site, node),
      ast.PostfixExpression(:final operator, :final operand)
          when operator.type == TokenType.BANG =>
        _NullCheck(site, operand),
      ast.ThisExpression() => _This(site),
      ast.ListLiteral() || ast.SetOrMapLiteral() => _CollectionLiteral(site),
      ast.ParenthesizedExpression(:final expression) => _Parenthesized(
        site,
        expression,
      ),
      _ => _OtherExpression(site),
    };
  }

  AccessOperator _operator(Token token) => switch (token.type) {
    TokenType.PERIOD => AccessOperator.period,
    TokenType.QUESTION_PERIOD => AccessOperator.questionPeriod,
    TokenType.PERIOD_PERIOD => AccessOperator.cascade,
    _ => AccessOperator.questionCascade,
  };

  Use useOf(ast.Expression node) {
    ast.AstNode current = node;
    while (true) {
      switch (current.parent) {
        case final ast.ParenthesizedExpression parent:
          current = parent;
        case final ast.AsExpression parent when parent.expression == current:
          current = parent;
        default:
          return _useAt(current);
      }
    }
  }

  Use _useAt(ast.AstNode node) => switch (node.parent) {
    ast.PropertyAccess(:final ast.Expression? target) ||
    ast.MethodInvocation(:final ast.Expression? target) ||
    ast.IndexExpression(:final ast.Expression? target) ||
    ast.CascadeExpression(
      :final ast.Expression? target,
    ) when target == node => const ReceiverUse(),
    ast.FunctionExpressionInvocation(:final function) when function == node =>
      const ReceiverUse(),
    ast.PostfixExpression(:final operator)
        when operator.type == TokenType.BANG =>
      const NullCheckUse(),
    ast.NamedArgument(:final name, :final parent?) => _argumentUse(
      parent,
      name.lexeme,
    ),
    final ast.ArgumentList list => _argumentUse(list, null),
    _ => const OtherUse(),
  };

  Use _argumentUse(ast.AstNode list, String? name) => switch (list.parent) {
    final ast.Expression call
        when call is ast.MethodInvocation ||
            call is ast.InstanceCreationExpression ||
            call is ast.FunctionExpressionInvocation =>
      ArgumentUse(expression(call) as Call, name: name),
    _ => const OtherUse(),
  };

  /// Today's `EnclosingDeclaration` walk, returning model elements.
  (Declaration?, Member?) enclosing(ast.AstNode node) {
    Declaration? declaration;
    Member? member;
    for (ast.AstNode? n = node; n != null; n = n.parent) {
      switch (n) {
        case ast.MethodDeclaration() || ast.ConstructorDeclaration():
          member = _members[n];
        case ast.VariableDeclaration(
          parent: ast.VariableDeclarationList(parent: ast.FieldDeclaration()),
        ):
          member = _members[n];
        case ast.VariableDeclaration(
          parent: ast.VariableDeclarationList(
            parent: ast.TopLevelVariableDeclaration(),
          ),
        ):
          declaration = _declarations[n];
        case ast.VariableDeclarationList(
          :final variables,
          parent: ast.FieldDeclaration(),
        ):
          member ??= _members[variables.first];
        case ast.VariableDeclarationList(
          :final variables,
          parent: ast.TopLevelVariableDeclaration(),
        ):
          declaration ??= _declarations[variables.first];
        case ast.CompilationUnitMember():
          declaration ??= _declarations[n];
      }
    }
    return (declaration, member);
  }

  // --- Types ---------------------------------------------------------------

  TypeReference type(ast.TypeAnnotation node) =>
      _types[node] ??= switch (node) {
        ast.NamedType(:final name, :final importPrefix, :final typeArguments) =>
          _TypeReference(
            this,
            node,
            name.lexeme,
            importPrefix?.name.lexeme,
            typeArguments?.arguments ?? const [],
          ),
        _ => _TypeReference(this, node, null, null, const []),
      };
}

extension on ast.Expression? {
  Expression? let(Expression Function(ast.Expression) f) =>
      this == null ? null : f(this!);
}

class _Collector extends GeneralizingAstVisitor<void> {
  _Collector(this.builder);

  final _Builder builder;
  final List<Expression> expressions = [];
  final List<TypeReference> types = [];

  @override
  void visitAnnotation(ast.Annotation node) {
    // The annotation's name and constructor name aren't expressions.
    node.typeArguments?.accept(this);
    node.arguments?.accept(this);
  }

  @override
  void visitConstructorName(ast.ConstructorName node) => node.type.accept(this);

  @override
  void visitMethodInvocation(ast.MethodInvocation node) {
    expressions.add(builder.expression(node));
    node.target?.accept(this);
    node.typeArguments?.accept(this);
    node.argumentList.accept(this);
  }

  @override
  void visitPrefixedIdentifier(ast.PrefixedIdentifier node) {
    expressions.add(builder.expression(node));
    node.prefix.accept(this);
  }

  @override
  void visitPropertyAccess(ast.PropertyAccess node) {
    expressions.add(builder.expression(node));
    node.target?.accept(this);
  }

  @override
  void visitNode(ast.AstNode node) {
    if (node is ast.Expression) expressions.add(builder.expression(node));
    if (node is ast.TypeAnnotation) types.add(builder.type(node));
    super.visitNode(node);
  }
}

// --- Model implementations ----------------------------------------------------

class _DartFile implements DartFile {
  _DartFile({
    required this.path,
    required this.directories,
    required this.declarations,
    required this.expressions,
    required this.typeReferences,
  });

  @override
  final String path;
  @override
  final List<String> directories;
  @override
  final List<Declaration> declarations;
  @override
  final List<Expression> expressions;
  @override
  final List<TypeReference> typeReferences;
}

abstract class _Type implements TypeDeclaration {
  _Type(this.name, this.offset, this.annotations);

  static _Type of(
    _Builder b,
    _Type Function(String?, int, List<Annotation>) create,
    String? name,
    int offset,
    List<ast.Annotation> metadata,
    List<ast.ClassMember> body,
  ) {
    final annotations = b._annotations(metadata);
    final type = create(name, offset, annotations);
    for (final node in body) {
      switch (node) {
        case ast.MethodDeclaration():
          type.methods.add(
            b._members[node] = _Method(
              name: node.name.lexeme,
              offset: node.name.offset,
              kind: b._kind(
                isGetter: node.isGetter,
                isSetter: node.isSetter,
                isOperator: node.isOperator,
              ),
              isStatic: node.isStatic,
              isAbstract: node.body is ast.EmptyFunctionBody,
              isExternal: node.externalKeyword != null,
              parameters: b._parameters(node.parameters),
              returned: () => b._returned(node.body),
            ),
          );
        case ast.ConstructorDeclaration():
          type.constructors.add(
            b._members[node] = _Constructor(
              name: node.name?.lexeme,
              offset: node.name?.offset ?? node.offset,
              isFactory: node.factoryKeyword != null,
              isExternal: node.externalKeyword != null,
              parameters: b._parameters(node.parameters),
              returned: () => b._returned(node.body),
            ),
          );
        case ast.FieldDeclaration():
          for (final variable in node.fields.variables) {
            type.fields.add(
              b._members[variable] = _Field(
                name: variable.name.lexeme,
                offset: variable.name.offset,
                isStatic: node.isStatic,
              ),
            );
          }
        default:
      }
    }
    return type;
  }

  @override
  final String? name;
  @override
  final int offset;
  @override
  final List<Annotation> annotations;
  @override
  final List<Method> methods = [];
  @override
  final List<Constructor> constructors = [];
  @override
  final List<Field> fields = [];
}

class _Class extends _Type implements ClassDeclaration {
  _Class(super.name, super.offset, super.annotations);
}

class _Mixin extends _Type implements MixinDeclaration {
  _Mixin(super.name, super.offset, super.annotations);
}

class _Enum extends _Type implements EnumDeclaration {
  _Enum(super.name, super.offset, super.annotations);
}

class _Extension extends _Type implements ExtensionDeclaration {
  _Extension(super.name, super.offset, super.annotations);
}

class _ExtensionType extends _Type implements ExtensionTypeDeclaration {
  _ExtensionType(super.name, super.offset, super.annotations);
}

class _TopLevelFunction implements TopLevelFunction {
  _TopLevelFunction({
    required this.name,
    required this.offset,
    required this.kind,
    required this.parameters,
  });

  @override
  final String name;
  @override
  final int offset;
  @override
  final FunctionKind kind;
  @override
  final List<Parameter> parameters;
}

class _TopLevelVariable implements TopLevelVariable {
  _TopLevelVariable({
    required this.name,
    required this.offset,
    required this.isConst,
  });

  @override
  final String name;
  @override
  final int offset;
  @override
  final bool isConst;
}

class _Method implements Method {
  _Method({
    required this.name,
    required this.offset,
    required this.kind,
    required this.isStatic,
    required this.isAbstract,
    required this.isExternal,
    required this.parameters,
    required Expression? Function() returned,
  }) : _returned = returned;

  @override
  final String name;
  @override
  final int offset;
  @override
  final FunctionKind kind;
  @override
  final bool isStatic;
  @override
  final bool isAbstract;
  @override
  final bool isExternal;
  @override
  final List<Parameter> parameters;
  final Expression? Function() _returned;
  @override
  Expression? get returnExpression => _returned();
}

class _Constructor implements Constructor {
  _Constructor({
    required this.name,
    required this.offset,
    required this.isFactory,
    required this.isExternal,
    required this.parameters,
    required Expression? Function() returned,
  }) : _returned = returned;

  @override
  final String? name;
  @override
  final int offset;
  @override
  final bool isFactory;
  @override
  final bool isExternal;
  @override
  final List<Parameter> parameters;
  final Expression? Function() _returned;
  @override
  Expression? get returnExpression => _returned();
}

class _Field implements Field {
  _Field({required this.name, required this.offset, required this.isStatic});

  @override
  final String name;
  @override
  final int offset;
  @override
  final bool isStatic;
}

class _Parameter implements Parameter {
  _Parameter({
    required this.name,
    required this.isPositional,
    required this.isNamed,
    required this.isFunction,
  });

  @override
  final String? name;
  @override
  final bool isPositional;
  @override
  final bool isNamed;
  @override
  final bool isFunction;
}

class _Annotation implements Annotation {
  _Annotation({
    required this.offset,
    required this.name,
    required this.prefix,
    required this.arguments,
  });

  @override
  final int offset;
  @override
  final String name;
  @override
  final String? prefix;
  @override
  final List<Argument> arguments;
}

class _Argument implements Argument {
  _Argument(this._builder, this.name, this._node);

  final _Builder _builder;
  final ast.Expression _node;
  @override
  final String? name;

  @override
  Expression get value => _builder.expression(_node);

  @override
  bool get isLiteral => switch (_node) {
    ast.BooleanLiteral() ||
    ast.IntegerLiteral() ||
    ast.DoubleLiteral() ||
    ast.SimpleStringLiteral() ||
    ast.NullLiteral() => true,
    _ => false,
  };

  @override
  Object? get literal => switch (_node) {
    ast.BooleanLiteral(:final value) => value,
    ast.IntegerLiteral(:final value) => value,
    ast.DoubleLiteral(:final value) => value,
    ast.SimpleStringLiteral(:final value) => value,
    _ => null,
  };
}

/// What every expression shares: its node and the builder that maps
/// surrounding nodes to model elements.
class _Site {
  _Site(this.builder, this.node);

  final _Builder builder;
  final ast.Expression node;
  late final (Declaration?, Member?) enclosing = builder.enclosing(node);
}

mixin _Expression implements Expression {
  _Site get site;

  @override
  int get offset => site.node.offset;

  @override
  Use get use => site.builder.useOf(site.node);

  @override
  Declaration? get declaration => site.enclosing.$1;

  @override
  Member? get member => site.enclosing.$2;

  Expression _map(ast.Expression node) => site.builder.expression(node);
}

class _Await with _Expression implements Await {
  _Await(this.site, this.offset, this._node);

  @override
  final _Site site;
  @override
  final int offset;
  final ast.AwaitExpression _node;

  @override
  Expression get operand => _map(_node.expression);
}

class _MethodCall with _Expression implements MethodCall {
  _MethodCall(this.site, this._node);

  @override
  final _Site site;
  final ast.MethodInvocation _node;

  @override
  Expression? get target => _node.realTarget.let(_map);

  @override
  AccessOperator? get operator => switch (_node.operator) {
    final token? => site.builder._operator(token),
    null => null,
  };

  @override
  String get name => _node.methodName.name;

  @override
  List<Argument> get arguments => site.builder._arguments(_node.argumentList);
}

class _InstanceCreation with _Expression implements InstanceCreation {
  _InstanceCreation(this.site, this._node, this.name);

  @override
  final _Site site;
  final ast.InstanceCreationExpression _node;
  @override
  final String name;

  @override
  List<Argument> get arguments => site.builder._arguments(_node.argumentList);
}

class _FunctionCall with _Expression implements FunctionCall {
  _FunctionCall(this.site, this._node);

  @override
  final _Site site;
  final ast.FunctionExpressionInvocation _node;

  @override
  Expression get callee => _map(_node.function);

  @override
  List<Argument> get arguments => site.builder._arguments(_node.argumentList);
}

class _Reference with _Expression implements Reference {
  _Reference(this.site, this._target, this.operator, this.name);

  @override
  final _Site site;
  final ast.Expression? _target;
  @override
  final AccessOperator? operator;
  @override
  final String name;

  @override
  Expression? get target => _target.let(_map);
}

class _Cast with _Expression implements Cast {
  _Cast(this.site, this._node);

  @override
  final _Site site;
  final ast.AsExpression _node;

  @override
  Expression get operand => _map(_node.expression);

  @override
  TypeReference get type => site.builder.type(_node.type);
}

class _NullCheck with _Expression implements NullCheck {
  _NullCheck(this.site, this._operand);

  @override
  final _Site site;
  final ast.Expression _operand;

  @override
  Expression get operand => _map(_operand);
}

class _This with _Expression implements This {
  _This(this.site);

  @override
  final _Site site;
}

class _CollectionLiteral with _Expression implements CollectionLiteral {
  _CollectionLiteral(this.site);

  @override
  final _Site site;
}

class _Parenthesized with _Expression implements Parenthesized {
  _Parenthesized(this.site, this._inner);

  @override
  final _Site site;
  final ast.Expression _inner;

  @override
  Expression get expression => _map(_inner);
}

class _OtherExpression with _Expression implements OtherExpression {
  _OtherExpression(this.site);

  @override
  final _Site site;
}

class _TypeReference implements TypeReference {
  _TypeReference(
    this._builder,
    this._node,
    this.name,
    this.prefix,
    this._arguments,
  );

  final _Builder _builder;
  final ast.TypeAnnotation _node;
  final List<ast.TypeAnnotation> _arguments;
  late final (Declaration?, Member?) _enclosing = _builder.enclosing(_node);

  @override
  final String? name;
  @override
  final String? prefix;

  @override
  int get offset => _node.offset;

  @override
  List<TypeReference> get typeArguments => [
    for (final argument in _arguments) _builder.type(argument),
  ];

  @override
  Declaration? get declaration => _enclosing.$1;

  @override
  Member? get member => _enclosing.$2;
}
