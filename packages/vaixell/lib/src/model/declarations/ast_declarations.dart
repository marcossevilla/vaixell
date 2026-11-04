part of '../model.dart';

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
