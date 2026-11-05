part of '../model.dart';

/// What every type declaration shares: a symbol, annotations and members.
mixin _AstTypeDeclaration implements TypeDeclaration {
  _AstDartFile get file;

  ast.AnnotatedNode get node;

  List<ast.ClassMember> get body;

  /// The header that holds a primary constructor, if any.
  ast.ClassNamePart? get namePart => null;

  @override
  late final String? symbol = file.symbolOf(this, null);

  @override
  late final List<Annotation> annotations = List.unmodifiable([
    for (final annotation in node.metadata) _AstAnnotation(file, annotation),
  ]);

  @override
  late final List<Member> members = List.unmodifiable([
    if (namePart case final ast.PrimaryConstructorDeclaration header)
      file.member(header)!,
    for (final member in body)
      if (member is ast.FieldDeclaration)
        for (final variable in member.fields.variables) file.member(variable)!
      else if (member is! ast.PrimaryConstructorBody)
        ?file.member(member),
  ]);

  @override
  late final List<Method> methods = List.unmodifiable(
    members.whereType<Method>(),
  );

  @override
  late final List<Constructor> constructors = List.unmodifiable(
    members.whereType<Constructor>(),
  );

  @override
  late final List<Field> fields = List.unmodifiable(members.whereType<Field>());
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
  ast.ClassNamePart get namePart => node.namePart;

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
  ast.ClassNamePart get namePart => node.namePart;

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
  ast.ClassNamePart get namePart => node.namePart;

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
  late final String? symbol = file.symbolOf(this, null);
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
  late final String? symbol = file.symbolOf(this, null);
}
