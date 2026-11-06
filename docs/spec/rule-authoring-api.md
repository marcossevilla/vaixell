# Spec: AST-free rule authoring API

**Status:** proposed, for approval in review.
**Map:** [#33](https://github.com/marcossevilla/vaixell/issues/33). Every section links the ticket that decided it.
**Vocabulary:** [`GLOSSARY.md`](https://github.com/marcossevilla/vaixell/pull/47).
**Evidence:** the [`prototype/expression-model`](https://github.com/marcossevilla/vaixell/tree/prototype/expression-model/packages/vaixell/prototype) branch, where every built-in rule runs on the model and passes today's tests (452 in total).

## Goal

Rules in `packages/vaixell` are written against a small model of a Dart file that vaixell owns, take typed options from config, and never touch the Dart AST.

Constraints:

- **Parse-only.** No type resolution and no `pub get`, as today.
- **Same behavior, same ids.** Every built-in rule keeps its behavior and its violation ids, so existing baselines keep matching. The one exception is code in primary constructors, which the model sees as constructors (see [Declarations and members](#declarations-and-members-35-36)).
- **No analyzer types in the public API.** Internals may wrap or extend analyzer classes, but no `package:analyzer` or `package:yaml` type is exported or appears in a public signature.
- **The public Dart API may break.** This is a breaking change for library users. The CLI and config stay compatible.

## A rule at a glance

```dart
import 'package:vaixell/vaixell.dart';

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
```

## Rules

### `Rule` ([#40](https://github.com/marcossevilla/vaixell/issues/40), [#46](https://github.com/marcossevilla/vaixell/issues/46))

A rule has an id and one method, `check(file)`, which returns findings. `check` makes no promise about order; the engine sorts ([#45](https://github.com/marcossevilla/vaixell/issues/45)).

```dart
sealed class RuleEntry {
  /// The id used in config and in violation ids, for example `static-method`.
  String get id;

  /// The severity used by `recommended` and when config only enables the rule.
  Severity get defaultSeverity;

  /// Whether `recommended` enables it.
  bool get recommended;
}

abstract base class const Rule() implements RuleEntry {
  @override
  Severity get defaultSeverity => Severity.error;

  @override
  bool get recommended => true;

  /// Whether to check [file] at all. When it's `false`, no `Checks…` hook runs.
  bool shouldCheck(DartFile file) => true;

  /// The findings in [file].
  List<Finding> check(DartFile file) => const [];
}
```

`Rule` loses `checksFilesWithErrors` ([#39](https://github.com/marcossevilla/vaixell/issues/39)). A rule never sees a file that doesn't parse.

### `Finding` ([#41](https://github.com/marcossevilla/vaixell/issues/41), [#37](https://github.com/marcossevilla/vaixell/issues/37))

Rules build findings by hand, as today. `Finding.at` takes the offset and symbol from a model element, so no rule spells a symbol by hand.

```dart
final class const Finding({
  required final int offset,
  required final String message,
  final String? symbol,
}) {
  /// A finding at [element]. Its symbol is the element's, followed by
  /// `@qualifier` when there's one, as in `ApiClient.getUser@decode`.
  new at(Reportable element, {required String message, String? qualifier});
}
```

The violation id stays `rule:path` or `rule:path:symbol`, with `#2`, `#3`… for repeats in source order. The engine assigns it, not the rule.

### `RuleFactory` ([#38](https://github.com/marcossevilla/vaixell/issues/38), [#39](https://github.com/marcossevilla/vaixell/issues/39))

A rule that takes options is registered as a factory that builds a configured rule from them. A rule without options is registered as the rule itself.

```dart
final class const RuleFactory(
  @override final String id,
  /// Builds the rule from one package's options.
  final Rule Function(OptionValue options) create, {
  @override final Severity defaultSeverity = Severity.error,
  @override final bool recommended = true,
}) implements RuleEntry;
```

- **Once per package.** The config loader calls `create` once for each package config that enables the rule, so options are parsed and checked once, not once per file.
- **Enabled without options.** `create` still runs, with an empty `OptionValue`. A rule that needs options fails through its readers, such as "`forbidden-import` needs `imports`", at the rule's line. There's no `requiresOptions` flag.
- **Plain rules reject options.** Giving options to a rule registered as a plain `Rule` fails with "`id` takes no options" at that line.

## Options

### In config ([#43](https://github.com/marcossevilla/vaixell/issues/43))

Options are nested under the rule. `id: severity` is the short form and `id: {severity: …, <options>}` the long form.

```yaml
vaixell:
  rules:
    static-method: warning
    forbidden-import:
      severity: error
      imports:
        - files: lib/domain/**
          forbid: [package:flutter/]
```

A rule only sees its own entry, without `severity`.

### `OptionValue` ([#38](https://github.com/marcossevilla/vaixell/issues/38), [#46](https://github.com/marcossevilla/vaixell/issues/46))

One type at every depth wraps a YAML node, without exposing `package:yaml`. Its typed readers throw a `ConfigException` with path, line and column whenever the value doesn't match.

| Member             | Returns                    | Throws when                                                                                                     |
| ------------------ | -------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `asString()`       | `String`                   | the value isn't a string                                                                                        |
| `asList()`         | `List<OptionValue>`        | the value isn't a list                                                                                          |
| `asMap()`          | `Map<String, OptionValue>` | the value isn't a map                                                                                           |
| `operator [](key)` | `OptionValue`              | the value isn't a map. A missing key returns a value whose readers report it as missing, at the map's position. |
| `allowOnly({...})` | `void`                     | the map has a key outside the set                                                                               |

Each rule parses its options by hand into plain Dart values. There's no schema and no code generation.

## Helpers ([#45](https://github.com/marcossevilla/vaixell/issues/45), [#46](https://github.com/marcossevilla/vaixell/issues/46))

The helpers are public and optional, and built on `check(file)`. A rule that looks at the whole file overrides `check` instead.

| Mixin                   | Hook                                                        | Visits                                              |
| ----------------------- | ----------------------------------------------------------- | --------------------------------------------------- |
| `ChecksDeclarations`    | `Finding? checkDeclaration(Declaration declaration)`        | `file.declarations`                                 |
| `ChecksMembers`         | `Finding? checkMember(TypeDeclaration type, Member member)` | members of every `TypeDeclaration`                  |
| `ChecksImports`         | `Finding? checkImport(DartFile file, Import import)`        | `file.imports`                                      |
| `ChecksExpressions`     | `Finding? checkExpression(Expression expression)`           | `file.expressions`                                  |
| `ChecksTypeAnnotations` | `Finding? checkTypeAnnotation(TypeAnnotation type)`         | `file.typeAnnotations`                              |
| `SkipsDirectories`      | `Set<String> get skippedDirectories`                        | turns `shouldCheck` off for files under any of them |

- **Composition.** The mixins chain through `super`, so they combine in any order. When `shouldCheck(file)` is `false`, no hook runs.
- **One finding per element.** Hooks return `Finding?`. A rule that needs several findings for one element overrides `check`. A default `Iterable<Finding>` hook can be added later without breaking anything.
- **Context only where needed.** `checkMember` gets its type and `checkImport` its file. A rule that needs other context uses `shouldCheck` or overrides `check`.

## The model

Everything a rule sees. All types are vaixell's; the implementation wraps the parse-only AST in private classes. Sealed families can only be implemented inside vaixell.

### `DartFile` ([#35](https://github.com/marcossevilla/vaixell/issues/35), [#36](https://github.com/marcossevilla/vaixell/issues/36))

```dart
abstract interface class DartFile {
  /// The POSIX path, relative to the repository root.
  String get path;

  /// The path relative to the package root, for example `lib/src/a.dart`.
  String get packagePath;

  /// The directories of [path], for example `['lib', 'src', 'models']`.
  List<String> get directories;

  /// Syntax errors, in source order. Empty for every file a rule sees.
  List<SyntaxError> get errors;

  /// The `import` directives, in source order.
  List<Import> get imports;

  /// The top-level declarations, in source order.
  List<Declaration> get declarations;

  /// Every expression, at any depth, in source order.
  List<Expression> get expressions;

  /// Every type annotation, at any depth, including type arguments, in source order.
  List<TypeAnnotation> get typeAnnotations;
}
```

### `Reportable` and symbols ([#37](https://github.com/marcossevilla/vaixell/issues/37))

`Reportable` is the sealed parent of everything a finding can point at: syntax errors, imports, declarations, members, expressions and type annotations. Each has an `offset` (its name, or its keyword when it has none) and a ready-made `symbol`:

| Element                        | Symbol                                                                            |
| ------------------------------ | --------------------------------------------------------------------------------- |
| Type declaration               | `Name`, or `<unnamed>` for an unnamed extension                                   |
| Top-level function or variable | `name`, or `name=` for a setter                                                   |
| Member                         | `Type.member`, `Type.member=` for a setter, `Type.new` for an unnamed constructor |
| Expression or type annotation  | the symbol of the declaration and member it's in                                  |
| Import                         | its URI                                                                           |
| Syntax error                   | `null`                                                                            |

There are no back-references: a `Member` doesn't know its declaration. Rules that need it get it from `checkMember(type, member)`.

### Imports ([#44](https://github.com/marcossevilla/vaixell/issues/44))

```dart
abstract interface class Import implements Reportable {
  /// The URI as written, for example `package:flutter/material.dart`.
  String get uri;

  /// `dart`, `package` or `relative`.
  ImportKind get kind;

  /// The imported file, relative to the repository root, for relative imports
  /// and imports of the file's own package (by its `pubspec.yaml` name).
  /// `null` otherwise.
  String? get path;
}
```

### Declarations and members ([#35](https://github.com/marcossevilla/vaixell/issues/35), [#36](https://github.com/marcossevilla/vaixell/issues/36))

- **Sealed `Declaration`:** `ClassDeclaration`, `MixinDeclaration`, `EnumDeclaration`, `ExtensionDeclaration`, `ExtensionTypeDeclaration`, `TopLevelFunction` and `TopLevelVariable` (one per declared name, with `isConst`).
- **Sealed `TypeDeclaration`** groups the first five: `name` (`null` only for an unnamed extension), `annotations`, `members` in source order (a primary constructor, declared in the header, first), and `methods`, `constructors` and `fields`.
- **`ExtensionDeclaration`:** `extendedType`, the `TypeAnnotation` after `on`.
- **`TopLevelFunction`:** `name` and `kind` (`FunctionKind`: function, getter, setter or operator).
- **Sealed `Member`:**
  - `Method`: `name`, `kind`, `isStatic`, `isAbstract` (no body), `isExternal`, `parameters`, `returnExpression`.
  - `Constructor`: `name` (`null` when unnamed), `isFactory`, `isExternal`, `parameters`, `returnExpression`. A primary constructor is one too, and code in its header or its `this : …;` body is in it, so findings there get `Type.new` or `Type.name` symbols instead of `Type`.
  - `Field`: one per declared name, with `name` and `isStatic`.
  - `returnExpression` is `e` for `=> e;` or `{ return e; }`, otherwise `null`.
- **`Parameter`:** `name`, `isPositional`, `isNamed`, `isFunction` (as in `T Function(Object?) fromJsonT`).
- **`Annotation`:** `name`, `prefix`, `arguments`.
- **`Argument`** (of an annotation or a call): `name` (`null` when positional), `value` (an `Expression`), and `literal` with `isLiteral` for `bool`, number, `String` and `null` literals.

### Code inside declarations ([#36](https://github.com/marcossevilla/vaixell/issues/36))

- **Sealed `Enclosed`**, the parent of expressions and type annotations: `declaration` and `member` it's written in. `declaration` is `null` in a library directive's annotation, a top-level variable declaration's annotation and typedefs. `member` is `null` when it's in the declaration itself.
- **Sealed `Expression`**, each with `use`, `unparenthesized`, `calledName` (the name of what it calls or reads, as `fetch` in `api.fetch()`) and `isPositionalArgumentOf(name)` (looking through parentheses and casts, as `json` in `User.fromJson(json)`):
  - `Await` (`operand`).
  - Sealed `Call` (`arguments`): `MethodCall` (`target`, `operator`, `name`), `InstanceCreation` (`name`, the last name before the arguments) and `FunctionCall` (`callee`). Without types, `User(…)` and `User.fromJson(…)` are method calls.
  - `Reference` (`target`, `operator`, `name`): `name`, `target.name`, `target?.name` or `..name`.
  - `Cast` (`operand`, `type`), `NullCheck` (`operand`), `This`, `CollectionLiteral`, `Parenthesized` (`expression`) and `OtherExpression`.
  - In a cascade, `target` is the cascade's target. `operator` is an `AccessOperator`: `period`, `questionPeriod`, `cascade` or `questionCascade`.
- **Sealed `Use`**, how a value is used, looking through parentheses and `as` casts: `ReceiverUse`, `NullCheckUse`, `ArgumentUse(call, name)` and `OtherUse`.
- **`TypeAnnotation`:** `name` (`null` for function and record types), `prefix`, `typeArguments`, and `cast` when it's the type of an `as`. A type annotation shared by several variables belongs to the first.

## Wiring rules in

### `Recommended.rules` and injection ([#42](https://github.com/marcossevilla/vaixell/issues/42), [#48](https://github.com/marcossevilla/vaixell/issues/48))

The caller passes a `List<RuleEntry>`. `package:vaixell` never picks the rule set for them.

- **`Recommended.rules`:** a `static const List<RuleEntry>` in reporting order, without `parse-error`, on a class so it stays clear of `top-level-variable`. The `recommended` preset enables its entries. It replaces `RuleRegistry`. Callers extend it (`[...Recommended.rules, myRule]`) or filter it by `id`. Removing an entry makes its id unknown to that executable.
- **Required at every step:** `Check(rules:)` and `WriteBaseline(rules:)` pass it to `PackageResolver.fromTree(rules:)`, which passes it to `ConfigLoader(tree, rules)`.
- **`Config`** holds a package's `ConfiguredRule`s, each a built `rule` with its `severity`, instead of severities by id. The loader builds them, running each factory once.
- **`Engine`** stays `const Engine()`. It runs the rules each package's config carries, plus `parse-error`. `Check` and `WriteBaseline` accept an engine only as a test seam.
- **CLI:** `VaixellCommandRunner({List<RuleEntry> rules = Recommended.rules})` passes the list to `CheckCommand(rules:)`, which requires it. `bin/vaixell.dart` uses the default.
- **`Package`** also carries its `pubspec.yaml` name, so the model can resolve own-package imports.

### Presets, unknown ids and `parse-error` ([#39](https://github.com/marcossevilla/vaixell/issues/39))

- **`parse-error`** is the engine's, not an injected rule. It's always on and keeps its id (`parse-error:path`) and message. Its severity is still configurable under `rules:`, and `off` is still rejected. When a file doesn't parse, it's the only finding for that file.
- **`recommended`** enables every injected entry at its `defaultSeverity`, except those with `recommended: false`. There's no `Preset` type.
- **Unknown ids** are checked against the injected entries' ids plus `parse-error`, with today's positioned "Unknown rule" error.

## Testing rules ([#49](https://github.com/marcossevilla/vaixell/issues/49))

`package:vaixell/testing.dart` is a second public library, not exported from `vaixell.dart`. It has no matchers, so `vaixell` takes no dependency on `package:test`. vaixell's own rule tests use only this public API, as third-party rule authors do.

Its helpers are methods on a const `RuleTester`, so the library stays clear of the `top-level-function` and `static-method` rules that vaixell checks itself with.

```dart
final class const RuleTester() {
  /// The findings of [rule] in [source], sorted by offset.
  List<Finding> checkSource(
    Rule rule,
    String source, {
    String path = 'lib/a.dart',
    TestPackage package = const TestPackage(path: ''),
  });

  /// The rule [factory] builds from the options in the YAML file at [fixture].
  Rule createRule(RuleFactory factory, {required String fixture});
}

/// Where [RuleTester.checkSource] places its file: the package directory,
/// relative to the repository root, and its `pubspec.yaml` name.
final class const TestPackage({required final String path, final String? name});
```

- **Paths** are repo-relative, the same form vaixell reports. `checkSource` throws an `ArgumentError` when `path` isn't under `package.path/lib/`.
- **Syntax errors** make `checkSource` throw a `FormatException`, naming each with its line and column.
- **Fixtures** hold only the rule's options, the entry without `severity`. An empty fixture means enabled without options. Option errors throw a `ConfigException` with the fixture's path, line and column.

```dart
const tester = RuleTester();
final rule = tester.createRule(forbiddenImport, fixture: 'test/fixtures/forbidden_import/domain.yaml');

test('flags Flutter in the domain layer', () {
  final findings = tester.checkSource(
    rule,
    "import 'package:flutter/material.dart';\n",
    path: 'packages/app/lib/domain/user.dart',
    package: const TestPackage(path: 'packages/app', name: 'app'),
  );
  expect(findings.map((f) => f.symbol), ['package:flutter/material.dart']);
});
```

## Public API changes

| Today                                                          | After                                                                                                                                                               |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Rule.check(ParsedFile)`                                       | `Rule.check(DartFile)`                                                                                                                                              |
| `Rule.checksFilesWithErrors`                                   | removed; `parse-error` is the engine's                                                                                                                              |
| `ParsedFile`, `enclosing_declaration.dart`                     | removed, replaced by the model                                                                                                                                      |
| `RuleRegistry`                                                 | `Recommended.rules`                                                                                                                                                 |
| `Presets`                                                      | `recommended` derived from the injected entries                                                                                                                     |
| `Config.severities`                                            | `Config.rules`, a list of `ConfiguredRule`                                                                                                                          |
| `ConfigLoader(tree)`, `PackageResolver.fromTree(root:, tree:)` | add a required `rules`                                                                                                                                              |
| `Check(root:)`, `WriteBaseline(root:)`                         | add a required `rules`                                                                                                                                              |
| `ConfigException.at`, `ConfigException.yaml`                   | removed from the public API; they took YAML types                                                                                                                   |
| —                                                              | new: `RuleEntry`, `RuleFactory`, `ConfiguredRule`, `OptionValue`, `Finding.at`, the model, the `Checks…` mixins, `SkipsDirectories`, `package:vaixell/testing.dart` |

## Every rule, expressed

The map is done when every built-in rule and #32's `forbidden-import` fit this spec. Each row below is a [prototype](https://github.com/marcossevilla/vaixell/tree/prototype/expression-model/packages/vaixell/prototype) rule that passes today's tests unchanged.

| Rule                    | Entry                               | Default | Built from                                                                | Model it reads                                                                                             | Symbol                              |
| ----------------------- | ----------------------------------- | ------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| `parse-error`           | engine                              | error   | —                                                                         | `DartFile.errors`                                                                                          | none                                |
| `top-level-function`    | `Rule`                              | error   | `ChecksDeclarations`                                                      | `TopLevelFunction` `name`, `kind`                                                                          | `name`, `name=`                     |
| `top-level-variable`    | `Rule`                              | error   | `ChecksDeclarations`                                                      | `TopLevelVariable` `name`, `isConst`                                                                       | `name`                              |
| `extension-declaration` | `Rule`                              | error   | `ChecksDeclarations`                                                      | `ExtensionDeclaration`, `ExtensionTypeDeclaration`                                                         | `Name`, `<unnamed>`                 |
| `static-method`         | `Rule`                              | error   | `ChecksMembers`                                                           | `Method` `isStatic`, `kind`                                                                                | `Type.member`                       |
| `raw-json`              | `Rule`                              | error   | `ChecksExpressions`, `ChecksTypeAnnotations`, `SkipsDirectories {models}` | `MethodCall`, `Reference`, `ArgumentUse`, `CollectionLiteral`, `Cast`, `TypeAnnotation`, `Enclosed.member` | `<where>@decode`, `@encode`, `@map` |
| `generated-json`        | `Rule`                              | warning | `ChecksMembers`                                                           | `Constructor`, `Method`, `parameters`, `returnExpression`, `Annotation` literals                           | `Type.fromJson`, `Type.toJson`      |
| `await-receiver`        | `Rule`                              | warning | `ChecksExpressions`                                                       | `Await`, `ReceiverUse`, `NullCheckUse`, `MethodCall`, `Reference`, `FunctionCall`                          | `<where>@calledName`                |
| `forbidden-import`      | `RuleFactory`, `recommended: false` | error   | `ChecksImports`                                                           | `Import` `uri`, `path`; `DartFile.packagePath`                                                             | the import's URI                    |

`forbidden-import` is the one rule with options:

```dart
const forbiddenImport = RuleFactory(
  'forbidden-import',
  ForbiddenImportRule.fromOptions,
  recommended: false,
);

final class const ForbiddenImportRule(final List<ImportBoundary> boundaries)
    extends Rule
    with ChecksImports {
  factory fromOptions(OptionValue options) {
    options.allowOnly({'imports'});
    return ForbiddenImportRule([
      for (final entry in options['imports'].asList())
        ImportBoundary.fromOptions(entry),
    ]);
  }

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
```

`ImportBoundary.fromOptions` reads `files` and `forbid` the same way, with `allowOnly`, `asString` and `asList`. It throws `entry['files'].error(…)` for a glob that doesn't parse (see gap 3).

## Gaps for review

Writing this spec down turned up four details the tickets don't settle. Each has a proposal; approving the spec approves them.

1. **Where `defaultSeverity` and `recommended` live.** #39 derives `recommended` from each entry's `defaultSeverity` and a `recommended: false` opt-out, but only shows them on `RuleFactory`. **Proposal:** both are on `RuleEntry`, as above. `Rule` keeps today's `defaultSeverity` getter (default `error`) and gains `recommended` (default `true`). For a factory, the factory's values count and the built rule's are ignored.
2. **A factory's rule with another id.** Nothing stops `create` from returning a rule whose `id` differs from the factory's. **Proposal:** the config loader throws a `StateError` naming both ids, since it's a bug in the rule, not in config.
3. **Errors for values that read fine but aren't valid.** #32 needs positioned errors for bad globs, which the type readers can't catch. **Proposal:** `OptionValue.error(String message)` returns a `ConfigException` at that value's position, for the rule to throw.
4. **Readers beyond strings, lists and maps.** #38 names `asString`, `asList`, `asMap`, `[]` and `allowOnly`. No rule needs booleans or numbers yet. **Proposal:** leave them out until a rule needs them, since adding them later doesn't break anything.

## Out of scope

- Relationships across files beyond one file's imports.
- Plugin loading and discovery of rule packages, and scaffolding a rule package.
- Moving the built-in rules into separate packages, or exporting each built-in rule class.
- Implementing this spec and rewriting the built-in rules.
- Custom test matchers, a `vaixell_test` package, and fixtures shaped like a full config.
- #29 inline ignores, #30 rule doc links, #31 `--fatal-warnings` and `info` severity, and #32's `allow:` form.
