// PROTOTYPE: the base class and mixins rules are composed from, for
// https://github.com/marcossevilla/vaixell/issues/36. Never merged.
//
// `check(file)` stays the only contract (#40). The `Checks…` mixins
// implement it by visiting one kind of element and asking the rule about
// each. They chain through `super`, so they combine in any order, and
// `shouldCheck` lets a mixin such as `SkipsDirectories` turn a file off.

import 'package:vaixell/src/rules/rule.dart' show Finding;

import 'model.dart';

/// A rule written against the model.
abstract base class const ModelRule() {
  /// The id used in config and in violation ids.
  String get id;

  /// Whether to check [file] at all.
  bool shouldCheck(DartFile file) => true;

  /// The findings in [file], in source order.
  List<Finding> check(DartFile file) => const [];
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

/// Spells finding symbols the way today's violation ids do.
base mixin NamesFindings on ModelRule {
  /// `Container.member`, `member` or `Container` for where [code] is, or
  /// `null` outside any declaration. With [at], the symbol ends in `@at`,
  /// as in `ApiClient.getUser@decode`.
  ///
  /// A stand-in for whatever "Where finding symbols come from" (#37)
  /// decides.
  String? symbolOf(Enclosed code, {String? at}) {
    final enclosing = _enclosing(code);
    return at == null ? enclosing : '${enclosing ?? ''}@$at';
  }

  String? _enclosing(Enclosed code) {
    final container = switch (code.declaration) {
      TypeDeclaration(:final name) => name ?? '<unnamed>',
      TopLevelFunction(:final name, kind: FunctionKind.setter) => '$name=',
      TopLevelFunction(:final name) || TopLevelVariable(:final name) => name,
      null => null,
    };
    final member = switch (code.member) {
      Method(:final name, kind: FunctionKind.setter) => '$name=',
      Method(:final name) || Field(:final name) => name,
      Constructor(:final name) => name ?? 'new',
      null => null,
    };
    return member == null ? container : '$container.$member';
  }
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
