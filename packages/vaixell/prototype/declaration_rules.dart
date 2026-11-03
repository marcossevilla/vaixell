// PROTOTYPE: the declaration and file rules composed from rule.dart, for
// https://github.com/marcossevilla/vaixell/issues/36. Never merged.
//
// static-method, top-level-function, top-level-variable,
// extension-declaration and parse-error behave exactly like
// packages/vaixell/lib/src/rules/. forbidden-import sketches #32, with its
// options passed to the constructor until "Dart API for rule options" (#38)
// decides how rules take them.

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import 'model.dart';
import 'rule.dart';

/// Reports static methods, getters and setters.
final class const StaticMethodRule() extends Rule with ChecksMembers {
  @override
  String get id => 'static-method';

  @override
  Finding? checkMember(TypeDeclaration type, Member member) => switch (member) {
    Method(isStatic: true, :final kind, :final name) => Finding.at(
      member,
      message:
          'Static ${kind.asMember} `${type.name ?? '<unnamed>'}.$name` is not '
          'allowed. Use an instance member instead.',
    ),
    _ => null,
  };
}

extension on FunctionKind {
  /// `method`, `getter` or `setter`.
  String get asMember => this == FunctionKind.function ? 'method' : name;
}

/// Reports top-level functions, getters and setters, except `main`.
final class const TopLevelFunctionRule() extends Rule with ChecksDeclarations {
  @override
  String get id => 'top-level-function';

  @override
  Finding? checkDeclaration(Declaration declaration) => switch (declaration) {
    TopLevelFunction(name: 'main', kind: FunctionKind.function) => null,
    TopLevelFunction(:final kind, :final name) => Finding.at(
      declaration,
      message:
          'Top-level ${kind.name} `$name` is not allowed. Move it into a '
          'class.',
    ),
    _ => null,
  };
}

/// Reports top-level variables and constants.
final class const TopLevelVariableRule() extends Rule with ChecksDeclarations {
  @override
  String get id => 'top-level-variable';

  @override
  Finding? checkDeclaration(Declaration declaration) => switch (declaration) {
    TopLevelVariable(:final isConst, :final name) => Finding.at(
      declaration,
      message:
          'Top-level ${isConst ? 'constant' : 'variable'} `$name` is not '
          'allowed. Move it into a class.',
    ),
    _ => null,
  };
}

/// Reports extensions and extension types.
final class const ExtensionDeclarationRule()
    extends Rule
    with ChecksDeclarations {
  @override
  String get id => 'extension-declaration';

  @override
  Finding? checkDeclaration(Declaration declaration) => switch (declaration) {
    ExtensionDeclaration(name: null) => Finding.at(
      declaration,
      message: 'Unnamed extensions are not allowed. Use a class instead.',
    ),
    ExtensionDeclaration(:final name?) => Finding.at(
      declaration,
      message: 'Extension `$name` is not allowed. Use a class instead.',
    ),
    ExtensionTypeDeclaration(:final name) => Finding.at(
      declaration,
      message: 'Extension type `$name` is not allowed. Use a class instead.',
    ),
    _ => null,
  };
}

/// Reports the first syntax error, and how many more there are.
///
/// It looks at the whole file, so it overrides `check` instead of mixing in
/// a `Checks…` mixin. Running it on files that don't parse is the engine's
/// call, which "Presets and parse errors with injected rules" (#39) decides.
final class const ParseErrorRule() extends Rule {
  @override
  String get id => 'parse-error';

  @override
  List<Finding> check(DartFile file) => switch (file.errors) {
    [] => const [],
    [final first, ...final more] => [
      Finding.at(
        first,
        message:
            'Syntax error: ${first.message}'
            '${more.isEmpty ? '' : ' (and ${more.length} more)'}',
      ),
    ],
  };
}

/// Files matching [files] can't import anything starting with one of
/// [forbid], whether it's matched against the import's URI or the repo
/// path it resolves to.
final class const ImportBoundary({
  required final String files,
  required final List<String> forbid,
});

/// Reports imports that cross an [ImportBoundary], as sketched in #32.
final class const ForbiddenImportRule(final List<ImportBoundary> boundaries)
    extends Rule
    with ChecksImports {
  @override
  String get id => 'forbidden-import';

  @override
  Finding? checkImport(DartFile file, Import import) {
    for (final boundary in boundaries) {
      if (boundary.applies(file) && boundary.forbids(import)) {
        return Finding.at(
          import,
          message:
              '`${import.uri}` is not allowed in `${boundary.files}`. '
              'Move the code that needs it out of this layer.',
        );
      }
    }
    return null;
  }
}

extension on ImportBoundary {
  bool applies(DartFile file) =>
      Glob(files, context: p.posix).matches(file.packagePath);

  bool forbids(Import import) => forbid.any(
    (prefix) =>
        import.uri.startsWith(prefix) ||
        (import.path?.startsWith(prefix) ?? false),
  );
}
