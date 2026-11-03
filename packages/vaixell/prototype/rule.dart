// PROTOTYPE: the base class and mixins rules are composed from, for
// https://github.com/marcossevilla/vaixell/issues/36. Never merged.
//
// `check(file)` stays the only contract (#40). The `Checks…` mixins
// implement it by visiting one kind of element and asking the rule about
// each. They chain through `super`, so they combine in any order, and
// `shouldCheck` lets a mixin such as `SkipsDirectories` turn a file off.
//
// `Finding` is redeclared here to show `Finding.at`. test/shim.dart turns
// it back into today's `Finding`.

import 'model.dart';

/// Something a rule found, before it gets an id. Today's `Finding` (#41),
/// plus [Finding.at].
final class const Finding({
  required final int offset,
  required final String message,
  final String? symbol,
}) {
  /// A finding at [element], whose symbol is [Located.symbol], followed by
  /// `@qualifier` when there's one, as in `ApiClient.getUser@decode`.
  new at(Located element, {required String message, String? qualifier})
    : this(
        offset: element.offset,
        message: message,
        symbol: qualifier == null
            ? element.symbol
            : '${element.symbol ?? ''}@$qualifier',
      );
}

/// A rule written against the model.
abstract base class const ModelRule() {
  /// The id used in config and in violation ids.
  String get id;

  /// Whether to check [file] at all.
  bool shouldCheck(DartFile file) => true;

  /// The findings in [file], in source order.
  List<Finding> check(DartFile file) => const [];
}

/// Calls [checkDeclaration] for every top-level declaration in the file.
base mixin ChecksDeclarations on ModelRule {
  Finding? checkDeclaration(Declaration declaration);

  @override
  List<Finding> check(DartFile file) => _addFindings(
    this,
    file,
    super.check(file),
    () => file.declarations.map(checkDeclaration),
  );
}

/// Calls [checkImport] for every `import` in the file.
base mixin ChecksImports on ModelRule {
  Finding? checkImport(DartFile file, Import import);

  @override
  List<Finding> check(DartFile file) => _addFindings(
    this,
    file,
    super.check(file),
    () => [for (final import in file.imports) checkImport(file, import)],
  );
}

/// Calls [checkExpression] for every expression in the file.
base mixin ChecksExpressions on ModelRule {
  Finding? checkExpression(Expression expression);

  @override
  List<Finding> check(DartFile file) => _addFindings(
    this,
    file,
    super.check(file),
    () => file.expressions.map(checkExpression),
  );
}

/// Calls [checkTypeReference] for every type annotation in the file.
base mixin ChecksTypeReferences on ModelRule {
  Finding? checkTypeReference(TypeReference type);

  @override
  List<Finding> check(DartFile file) => _addFindings(
    this,
    file,
    super.check(file),
    () => file.typeReferences.map(checkTypeReference),
  );
}

/// Calls [checkMember] for every member of every class, mixin, enum,
/// extension and extension type in the file.
base mixin ChecksMembers on ModelRule {
  Finding? checkMember(TypeDeclaration type, Member member);

  @override
  List<Finding> check(DartFile file) => _addFindings(
    this,
    file,
    super.check(file),
    () => [
      for (final type in file.declarations.whereType<TypeDeclaration>())
        for (final member in type.members) checkMember(type, member),
    ],
  );
}

/// Skips files under any of [skippedDirectories], such as `models`.
base mixin SkipsDirectories on ModelRule {
  Set<String> get skippedDirectories;

  @override
  bool shouldCheck(DartFile file) =>
      !file.directories.any(skippedDirectories.contains) &&
      super.shouldCheck(file);
}

/// [inherited] plus the non-null findings from [visit], in source order,
/// or nothing when [rule] skips [file].
List<Finding> _addFindings(
  ModelRule rule,
  DartFile file,
  List<Finding> inherited,
  Iterable<Finding?> Function() visit,
) {
  if (!rule.shouldCheck(file)) return const [];
  return [...inherited, ...visit().nonNulls]
    ..sort((a, b) => a.offset.compareTo(b.offset));
}
