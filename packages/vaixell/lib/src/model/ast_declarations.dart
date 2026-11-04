part of 'model.dart';

/// What every type declaration shares: a symbol, annotations and members.
mixin _AstTypeDeclaration implements TypeDeclaration {
  _AstDartFile get file;

  ast.AnnotatedNode get node;

  List<ast.ClassMember> get body;

  @override
  String? get symbol => file.symbolOf(this, null);

  @override
  List<Annotation> get annotations => [
    for (final annotation in node.metadata) _AstAnnotation(file, annotation),
  ];

  @override
  List<Member> get members => [
    for (final member in body)
      if (member is ast.FieldDeclaration)
        for (final variable in member.fields.variables) file.member(variable)!
      else
        ?file.member(member),
  ];

  @override
  List<Method> get methods => members.whereType<Method>().toList();

  @override
  List<Constructor> get constructors =>
      members.whereType<Constructor>().toList();

  @override
  List<Field> get fields => members.whereType<Field>().toList();
}

final class _AstClass(
  @override final _AstDartFile file,
  @override final ast.ClassDeclaration node,
) with _AstTypeDeclaration implements ClassDeclaration {
  @override
  String get name => node.namePart.typeName.lexeme;

  @override
  int get offset => node.namePart.typeName.offset;

  @override
  List<ast.ClassMember> get body => node.body.members;
}

final class _AstMixin(
  @override final _AstDartFile file,
  @override final ast.MixinDeclaration node,
) with _AstTypeDeclaration implements MixinDeclaration {
  @override
  String get name => node.name.lexeme;

  @override
  int get offset => node.name.offset;

  @override
  List<ast.ClassMember> get body => node.body.members;
}

final class _AstEnum(
  @override final _AstDartFile file,
  @override final ast.EnumDeclaration node,
) with _AstTypeDeclaration implements EnumDeclaration {
  @override
  String get name => node.namePart.typeName.lexeme;

  @override
  int get offset => node.namePart.typeName.offset;

  @override
  List<ast.ClassMember> get body => node.body.members;
}

final class _AstExtension(
  @override final _AstDartFile file,
  @override final ast.ExtensionDeclaration node,
) with _AstTypeDeclaration implements ExtensionDeclaration {
  @override
  String? get name => node.name?.lexeme;

  @override
  int get offset => (node.name ?? node.extensionKeyword).offset;

  @override
  List<ast.ClassMember> get body => node.body.members;
}

final class _AstExtensionType(
  @override final _AstDartFile file,
  @override final ast.ExtensionTypeDeclaration node,
) with _AstTypeDeclaration implements ExtensionTypeDeclaration {
  @override
  String get name => node.namePart.typeName.lexeme;

  @override
  int get offset => node.namePart.typeName.offset;

  @override
  List<ast.ClassMember> get body => node.body.members;
}

final class _AstTopLevelFunction(
  final _AstDartFile file,
  final ast.FunctionDeclaration node,
) implements TopLevelFunction {
  @override
  String get name => node.name.lexeme;

  @override
  int get offset => node.name.offset;

  @override
  FunctionKind get kind =>
      file.kind(isGetter: node.isGetter, isSetter: node.isSetter);

  @override
  String? get symbol => file.symbolOf(this, null);
}

final class _AstTopLevelVariable(
  final _AstDartFile file,
  final ast.VariableDeclaration node,
) implements TopLevelVariable {
  @override
  String get name => node.name.lexeme;

  @override
  int get offset => node.name.offset;

  @override
  bool get isConst => (node.parent! as ast.VariableDeclarationList).isConst;

  @override
  String? get symbol => file.symbolOf(this, null);
}

final class _AstMethod(
  final _AstDartFile file,
  final ast.MethodDeclaration node,
) implements Method {
  @override
  String? get symbol => file.symbolOf(file.enclosing(node).declaration, this);

  @override
  String get name => node.name.lexeme;

  @override
  int get offset => node.name.offset;

  @override
  FunctionKind get kind => file.kind(
    isGetter: node.isGetter,
    isSetter: node.isSetter,
    isOperator: node.isOperator,
  );

  @override
  bool get isStatic => node.isStatic;

  @override
  bool get isAbstract => node.body is ast.EmptyFunctionBody;

  @override
  bool get isExternal => node.externalKeyword != null;

  @override
  List<Parameter> get parameters => file.parameters(node.parameters);

  @override
  Expression? get returnExpression => file.returnExpression(node.body);
}

final class _AstConstructor(
  final _AstDartFile file,
  final ast.ConstructorDeclaration node,
) implements Constructor {
  @override
  String? get symbol => file.symbolOf(file.enclosing(node).declaration, this);

  @override
  String? get name => node.name?.lexeme;

  /// The name, or the type name, `new` or `factory` when it's unnamed.
  @override
  int get offset =>
      (node.name ??
              node.typeName?.token ??
              node.newKeyword ??
              node.factoryKeyword)!
          .offset;

  @override
  bool get isFactory => node.factoryKeyword != null;

  @override
  bool get isExternal => node.externalKeyword != null;

  @override
  List<Parameter> get parameters => file.parameters(node.parameters);

  @override
  Expression? get returnExpression => file.returnExpression(node.body);
}

final class _AstField(
  final _AstDartFile file,
  final ast.VariableDeclaration node,
) implements Field {
  @override
  String? get symbol => file.symbolOf(file.enclosing(node).declaration, this);

  @override
  String get name => node.name.lexeme;

  @override
  int get offset => node.name.offset;

  @override
  bool get isStatic => (node.parent!.parent! as ast.FieldDeclaration).isStatic;
}

final class _AstParameter(final ast.FormalParameter node) implements Parameter {
  @override
  String? get name => node.name?.lexeme;

  @override
  bool get isPositional => node.isPositional;

  @override
  bool get isNamed => node.isNamed;

  @override
  bool get isFunction =>
      node.functionTypedSuffix != null || node.type is ast.GenericFunctionType;
}

final class _AstAnnotation(final _AstDartFile file, final ast.Annotation node)
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

final class _AstArgument(final _AstDartFile file, final ast.Argument node)
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
