import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/options/option_value.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Something a [Rule] found in a file, before it gets an id.
class const Finding({
  /// The character offset of the finding in the file.
  required final int offset,

  /// A human-readable description of the finding.
  required final String message,

  /// The symbol path that identifies the finding within its file, for
  /// example `Foo.bar`, or `null` when the file itself is the subject.
  final String? symbol,
}) {
  /// Creates a finding at [offset] in the file.
  this;

  /// A finding at [element]. Its symbol is the element's, followed by
  /// `@qualifier` when there's one, as in `ApiClient.getUser@decode`.
  new at(Reportable element, {required String message, String? qualifier})
    : this(
        offset: element.offset,
        message: message,
        symbol: qualifier == null
            ? element.symbol
            : '${element.symbol ?? ''}@$qualifier',
      );
}

/// An entry of the list of rules that vaixell runs: a [Rule], or a
/// [RuleFactory] that builds one from options.
sealed class RuleEntry {
  /// The id used in config and in violation ids, for example
  /// `static-method`.
  String get id;

  /// The severity used by `recommended` and when config only enables the
  /// rule.
  Severity get defaultSeverity;

  /// Whether `recommended` enables it.
  bool get recommended;
}

/// An architecture rule.
///
/// A rule overrides [check], or mixes in [ChecksDeclarations],
/// [ChecksMembers], [ChecksImports], [ChecksExpressions] or
/// [ChecksTypeAnnotations], which implement [check] by asking about one
/// kind of element at a time. They chain through `super`, so they combine
/// in any order.
abstract base class const Rule() implements RuleEntry {
  /// Allows subclasses to be const.
  this;

  @override
  Severity get defaultSeverity => Severity.error;

  @override
  bool get recommended => true;

  /// Whether to check [file] at all. When it's `false`, [check] isn't
  /// called and no `Checks…` hook runs.
  bool shouldCheck(DartFile file) => true;

  /// The findings in [file], in any order.
  List<Finding> check(DartFile file) => const [];

  /// [inherited] plus the findings [visit] returns, sorted by offset, or
  /// nothing when [shouldCheck] is `false` for [file].
  List<Finding> _addFindings(
    DartFile file,
    List<Finding> inherited,
    Iterable<Finding?> Function() visit,
  ) {
    if (!shouldCheck(file)) return const [];
    return [...inherited, ...visit().nonNulls]
      ..sort((a, b) => a.offset.compareTo(b.offset));
  }
}

/// A rule that takes options, registered as what builds it from them.
///
/// The config loader calls [create] once for each config that enables the
/// rule, with the rule's entry without `severity`, or with no options when
/// it's only enabled. Readers of [OptionValue] report bad options at their
/// position in the config file.
final class const RuleFactory(
  @override final String id,

  /// Builds the rule from one config's options. The rule's
  /// [RuleEntry.id] must be [id].
  final Rule Function(OptionValue options) create, {
  @override final Severity defaultSeverity = Severity.error,
  @override final bool recommended = true,
}) implements RuleEntry {
  /// Creates a factory for the rule [id] that [create] builds. Its
  /// [defaultSeverity] and [recommended] count, not the built rule's.
  this;
}

/// Builds the configured rule of a [RuleEntry]. Internal: it's never
/// exported.
class const RuleBuilder() {
  /// Creates the builder.
  this;

  /// The rule of [entry] with [options]: the rule itself, or what a factory
  /// builds from [options].
  ///
  /// Throws a [StateError] when a factory builds a rule with another id,
  /// which is a bug in the rule, not in config.
  Rule build(RuleEntry entry, OptionValue options) => switch (entry) {
    final Rule rule => rule,
    RuleFactory(:final id, :final create) => switch (create(options)) {
      final rule when rule.id == id => rule,
      final rule => throw StateError(
        'The factory for `$id` built a rule with id `${rule.id}`.',
      ),
    },
  };
}

/// Calls [checkDeclaration] for every top-level declaration in the file.
base mixin ChecksDeclarations on Rule {
  /// The finding for [declaration], if any.
  Finding? checkDeclaration(Declaration declaration);

  @override
  List<Finding> check(DartFile file) => _addFindings(
    file,
    super.check(file),
    () => file.declarations.map(checkDeclaration),
  );
}

/// Calls [checkMember] for every member of every class, mixin, enum,
/// extension and extension type in the file.
base mixin ChecksMembers on Rule {
  /// The finding for [member] of [type], if any.
  Finding? checkMember(TypeDeclaration type, Member member);

  @override
  List<Finding> check(DartFile file) => _addFindings(
    file,
    super.check(file),
    () => [
      for (final type in file.declarations.whereType<TypeDeclaration>())
        for (final member in type.members) checkMember(type, member),
    ],
  );
}

/// Calls [checkImport] for every `import` in the file.
base mixin ChecksImports on Rule {
  /// The finding for [import] in [file], if any.
  Finding? checkImport(DartFile file, Import import);

  @override
  List<Finding> check(DartFile file) => _addFindings(
    file,
    super.check(file),
    () => [for (final import in file.imports) checkImport(file, import)],
  );
}

/// Calls [checkExpression] for every expression in the file.
base mixin ChecksExpressions on Rule {
  /// The finding for [expression], if any.
  Finding? checkExpression(Expression expression);

  @override
  List<Finding> check(DartFile file) => _addFindings(
    file,
    super.check(file),
    () => file.expressions.map(checkExpression),
  );
}

/// Calls [checkTypeAnnotation] for every type annotation in the file.
base mixin ChecksTypeAnnotations on Rule {
  /// The finding for [type], if any.
  Finding? checkTypeAnnotation(TypeAnnotation type);

  @override
  List<Finding> check(DartFile file) => _addFindings(
    file,
    super.check(file),
    () => file.typeAnnotations.map(checkTypeAnnotation),
  );
}

/// Skips files under any of [skippedDirectories], such as `models`.
base mixin SkipsDirectories on Rule {
  /// The directory names whose files aren't checked, at any depth.
  Set<String> get skippedDirectories;

  @override
  bool shouldCheck(DartFile file) =>
      !file.directories.any(skippedDirectories.contains) &&
      super.shouldCheck(file);
}
