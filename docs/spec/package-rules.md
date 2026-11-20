# Spec: package rules and the library graph

**Status:** proposed, for approval in review.
**Map:** [#74](https://github.com/marcossevilla/vaixell/issues/74).
**Vocabulary:** [`GLOSSARY.md`](../../GLOSSARY.md), plus the terms in [Vocabulary](#vocabulary).
**Builds on:** the [rule authoring API](rule-authoring-api.md), which left relationships across files out of scope.

## Goal

A rule can read a whole package: its files, its `pubspec.yaml` and the graph of its libraries. Boundaries, circular dependencies, unused files and dependency hygiene are then rules like any other.

Constraints:

- **Parse-only.** No type resolution and no `pub get`, as today.
- **File rules don't change.** Same API, same behavior, same violation ids, so existing baselines keep matching.
- **One kind of result.** What a package rule reports becomes a violation with the same id format, severities, baselines, ignore comments and reporters.
- **No analyzer types in the public API**, as today.
- **No private path into the engine.** Built-in package rules use the public API, as built-in file rules do.

## A package rule at a glance

```dart
import 'package:vaixell/vaixell.dart';

/// Reports libraries that nothing imports.
final class const UnusedFileRule() extends PackageRule {
  @override
  String get id => 'unused-file';

  @override
  List<PackageFinding> check(DartPackage package) => [
    for (final library in package.libraries)
      if (!library.isEntryPoint && library.dependents.isEmpty)
        PackageFinding.file(
          library.path,
          message: 'Nothing imports `${library.path}`. Delete it or use it.',
        ),
  ];
}
```

## Vocabulary

Terms this spec adds to the glossary:

| Term            | Type             | Meaning                                                                                                                         |
| --------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Package rule    | `PackageRule`    | An architecture constraint that reads one package and returns package findings.                                                 |
| Package finding | `PackageFinding` | What a package rule reports at one place in a file of the package: a path, a line and column, a message and an optional symbol. |
| Dart package    | `DartPackage`    | One package as a package rule sees it: its path, name, pubspec and libraries.                                                   |
| Library         | `Library`        | A Dart file that isn't a part, together with its parts.                                                                         |
| Library graph   | —                | The libraries of the repository's packages and the imports and exports between them.                                            |
| Entry point     | —                | A library that is used from outside the graph: an executable, a test, or a public library.                                      |
| Directive       | `Directive`      | An `import`, `export` or `part` in a Dart file.                                                                                 |

"Rule" keeps its meaning: it reads one Dart file. Where both kinds are meant, this spec says "rule entry".

## Package rules

### `PackageRule`

A package rule has an id and one method, `check(package)`. It makes no promise about order; the engine sorts.

```dart
abstract base class const PackageRule() implements RuleEntry {
  @override
  Severity get defaultSeverity => Severity.error;

  @override
  bool get recommended => true;

  /// The findings in [package], in any order.
  List<PackageFinding> check(DartPackage package);
}
```

`PackageRuleFactory(id, create, {defaultSeverity, recommended})` builds a package rule from options, as `RuleFactory` does for a rule. It follows the same contract: once per package config, an empty `OptionValue` when the rule is only enabled, and a `StateError` when the built rule has another id.

### `PackageFinding`

```dart
final class const PackageFinding({
  /// The file, relative to the repository root. It must be in the package.
  required final String path,

  /// The 1-based line and column in that file.
  required final int line,
  required final int column,

  required final String message,

  /// The symbol that identifies the finding within its file, or `null` when
  /// the file itself is the subject.
  final String? symbol,
}) {
  /// A finding at [element] of [file]. Its symbol is the element's, followed
  /// by `@qualifier` when there's one.
  new at(DartFile file, Reportable element, {required String message, String? qualifier});

  /// A finding about the whole file at [path], at line 1, column 1.
  new file(String path, {required String message});
}
```

A package finding carries a line and column, not an offset, because it can point at a file that isn't Dart, such as `pubspec.yaml`.

### What the engine does with them

For each package, the engine runs the rules on each file as today, then each package rule once, and merges both by path.

- **Ids** keep the format `rule:path` or `rule:path:symbol`, with `#2`, `#3`… for repeats in a file, in source order.
- **Order** is by path, line and column. At the same position, rules come before package rules, each in the order of the injected list.
- **Ignore comments** apply to package findings in Dart files of the package, by the same line rule. They don't exist for other files, so a finding in `pubspec.yaml` is handled with rule options or a baseline.
- **Excluded and generated files** stay in the library graph, since they still import things, but findings in them are dropped.
- **A path outside the package** is a `StateError`: a bug in the rule, not in config.
- **`--git-diff`** runs package rules on both sides, since they only read the source tree.

## What a package rule sees

All types are vaixell's. Sealed families and these interfaces can only be implemented inside vaixell.

### `DartPackage`

```dart
abstract interface class DartPackage {
  /// The package directory, relative to the repository root, or `''`.
  String get path;

  /// The `name` in `pubspec.yaml`, or `null` when there's none.
  String? get name;

  /// What `pubspec.yaml` declares.
  Pubspec get pubspec;

  /// The libraries of the package, sorted by path.
  List<Library> get libraries;

  /// The library that the file at [path] is or is a part of, or `null`.
  Library? libraryOf(String path);
}
```

### `Library` and the graph

```dart
abstract interface class Library {
  /// The path of the file that defines the library.
  String get path;

  /// The defining file first, then its parts in directive order.
  List<DartFile> get files;

  /// Whether something outside the graph uses it. See [Entry points].
  bool get isEntryPoint;

  /// Whether a code generator wrote it.
  bool get isGenerated;

  /// One edge per `import` and `export`, in source order.
  List<LibraryEdge> get dependencies;

  /// The libraries that import or export this one, in any package of the
  /// repository, sorted by path.
  List<Library> get dependents;
}

abstract interface class LibraryEdge {
  /// The `import` or `export`, which a finding can point at.
  Directive get directive;

  /// The library it resolves to, in this package or another one of the
  /// repository. `null` for `dart:` URIs, packages outside the repository
  /// and files that don't exist.
  Library? get target;

  /// The package name of a `package:` URI, or `null`.
  String? get packageName;
}
```

How edges resolve, without `pub get`:

- **Relative URIs** resolve against the file.
- **`package:` URIs** resolve when the name is the package's own or that of another package vaixell discovered in the repository. Any other name is a package outside the repository, known only by `packageName`.
- **Conditional imports** give one edge per URI, the default and each `if` branch.
- **A missing target**, such as a `part` of a generated file that isn't written yet, is an edge with no `target`. It's never an error.

The graph always spans every package vaixell discovers, even when `vaixell check packages/a` checks one. Otherwise a library used only from another package would look unused.

### Entry points

By default, these libraries are entry points:

| Where                                                  | Why                                   |
| ------------------------------------------------------ | ------------------------------------- |
| `bin/**`, `tool/**`, `hook/**`                         | executables                           |
| `lib/main.dart`, `lib/main_*.dart`                     | app entry points                      |
| `test/**_test.dart`, `integration_test/**_test.dart`   | tests                                 |
| `example/**`                                           | examples                              |
| `lib/**` outside `lib/src/`, unless `publish_to: none` | the public API of a published package |

A package adds its own with globs, relative to the package:

```yaml
vaixell:
  entry:
    - lib/src/generated_routes.dart
```

### Which files are read

Today the engine lists `lib/`. For the graph it reads every `.dart` file of the package, except those in hidden directories, `build/` and nested packages.

- **Rules still check only `lib/`**, minus generated and excluded files, so nothing changes for them.
- **Each file is parsed once per run** and shared by the rules and the graph.
- **The generated suffixes** move from a constant in the engine to config, with today's list as the default (see gap 5).

### `Pubspec`

```dart
abstract interface class Pubspec {
  /// The path of the file, relative to the repository root.
  String get path;

  /// Whether `publish_to` is `none`.
  bool get isPrivate;

  /// The entries of `dependencies` and `dev_dependencies`, in source order.
  List<PubspecDependency> get dependencies;
}

abstract interface class PubspecDependency {
  String get name;
  bool get isDev;

  /// The 1-based line and column of the name.
  int get line;
  int get column;
}
```

## The model

### Directives

`DartFile` only has `imports` today. It gains exports and parts, under one sealed parent:

```dart
sealed class Directive implements Reportable {
  /// The URI as written, or `''` when it isn't a plain string.
  String get uri;

  /// `dart`, `package` or `relative`.
  ImportKind get kind;

  /// The file it points at, as `Import.path` resolves it today.
  String? get path;
}

abstract interface class Import implements Directive {
  String? get prefix;
  bool get isDeferred;
  List<String> get shownNames;
  List<String> get hiddenNames;

  /// The URIs of its `if` branches, in source order.
  List<String> get conditionalUris;
}

abstract interface class Export implements Directive {
  List<String> get shownNames;
  List<String> get hiddenNames;
  List<String> get conditionalUris;
}

abstract interface class Part implements Directive;
```

`DartFile` adds `exports`, `parts`, and `partOf` (the URI or library name after `part of`, or `null`). `ChecksImports` stays as it is. A `ChecksDirectives` mixin visits all three.

`Import.path` keeps resolving only relative and own-package URIs, so `forbidden-import` findings and ids don't depend on which other packages are in the repository. Resolution across packages lives in `LibraryEdge.target`.

## Wiring

- **`RuleEntry`** stays the sealed parent, now of four: `Rule`, `RuleFactory`, `PackageRule` and `PackageRuleFactory`. It keeps `id`, `defaultSeverity` and `recommended`. `build(options)` moves to each pair, since they build different things.
- **`RuleSet`** doesn't change: ids are unique across both kinds, and config names them all under `rules:`.
- **`Config`** keeps `rules` and gains `packageRules`, a list of `ConfiguredPackageRule`. `Config.configure` builds both from the entries.
- **`Check`, `WriteBaseline` and `VaixellCommandRunner`** keep taking one `List<RuleEntry>`, so callers add package rules the way they add rules today.
- **`recommended`** enables a package rule under the same condition as a rule. The built-in ones start with `recommended: false` (see gap 1).

Layers, as `test/architecture_test.dart` lists them:

| Layer    | Change                                                                             |
| -------- | ---------------------------------------------------------------------------------- |
| `model`  | gains the directives and the `DartPackage`, `Library` and `Pubspec` interfaces     |
| `graph`  | new: builds the library graph from parsed files. Imports `model`.                  |
| `rules`  | gains `PackageRule`, `PackageRuleFactory` and `PackageFinding`                     |
| `config` | gains `ConfiguredPackageRule` and the `entry` key                                  |
| `engine` | reads every Dart file, builds the graph, runs package rules. Also imports `graph`. |

## Testing package rules

`RuleTester` gains one method:

```dart
/// The findings of [rule] in a package with [files], by path relative to
/// the package, sorted by path, line and column.
List<PackageFinding> checkPackage(
  PackageRule rule, {
  required Map<String, String> files,
  TestPackage package = const TestPackage(path: ''),
});
```

`files` can hold a `pubspec.yaml`. Without one, the package has no dependencies and can be published.

## Every rule, expressed

The map is done when each row fits this spec.

| Rule                   | Entry         | Reads                                             | Reports at                | Symbol                |
| ---------------------- | ------------- | ------------------------------------------------- | ------------------------- | --------------------- |
| `forbidden-import`     | `RuleFactory` | `Import` `uri`, `path` (#32, unchanged)           | the import                | its URI               |
| `boundaries`           | `RuleFactory` | `Directive` `path`, `uri`; `DartFile.packagePath` | the directive             | its URI               |
| `circular-dependency`  | `PackageRule` | `Library.dependencies`                            | the import that closes it | its URI               |
| `unused-file`          | `PackageRule` | `Library.isEntryPoint`, `dependents`              | the file                  | none                  |
| `unused-dependency`    | `PackageRule` | `Pubspec.dependencies`, `LibraryEdge.packageName` | the `pubspec.yaml` entry  | the dependency's name |
| `missing-dependency`   | `PackageRule` | the same                                          | the first import of it    | the package name      |
| `misplaced-dependency` | `PackageRule` | the same, split by `lib/` and the rest            | the `pubspec.yaml` entry  | the dependency's name |

`boundaries` is a file rule: `Directive.path` already says which file an import points at, so the zone of both ends is known without the graph. Its config mirrors the map in `test/architecture_test.dart`:

```yaml
vaixell:
  rules:
    boundaries:
      severity: error
      zones:
        model: lib/src/model/**
        rules: lib/src/rules/**
        engine: lib/src/engine/**
      allow:
        model: []
        rules: [model]
        engine: [model, rules]
```

A file in no zone is unrestricted. A zone that `allow` doesn't list is a config error, as an unlisted layer fails the architecture test today.

## Public API changes

| Today                      | After                                                                                                                                                                                                                              |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RuleEntry.build(options)` | declared by `Rule` and `RuleFactory`, and by the two new package entries                                                                                                                                                           |
| `DartFile.imports`         | plus `exports`, `parts` and `partOf`                                                                                                                                                                                               |
| `Import`                   | implements `Directive`; gains `prefix`, `isDeferred`, the names and `conditionalUris`                                                                                                                                              |
| `Config.rules`             | plus `Config.packageRules`                                                                                                                                                                                                         |
| the engine checks `lib/`   | rules check `lib/`; the graph reads every Dart file of the package                                                                                                                                                                 |
| —                          | new: `PackageRule`, `PackageRuleFactory`, `PackageFinding`, `DartPackage`, `Library`, `LibraryEdge`, `Pubspec`, `PubspecDependency`, `Directive`, `Export`, `Part`, `ChecksDirectives`, `RuleTester.checkPackage`, the `entry` key |

## Gaps for review

Each has a proposal; approving the spec approves them.

1. **Which package rules `recommended` enables.** `recommended` is what runs with no config, so a rule added to it shows up as new violations in every repository. **Proposal:** the built-in package rules ship with `recommended: false` and are turned on by name. Whether the preset should hold facts about the code (unused, circular) instead of opinions (`static-method`) is a separate ticket.
2. **Syntax errors outside `lib/`.** The graph reads `bin/` and `test/`, where a file may not parse. **Proposal:** such a file is in the graph with the directives the parser recovered, and gets no `parse-error`, so runs don't gain violations for files that were never checked.
3. **`ImportKind` on exports and parts.** The name fits only one of the three. **Proposal:** rename it to `UriKind`, a breaking change that's cheap before 1.0.
4. **Config for the whole repository.** Zones and entry points are per package here, since config is. Rules between packages are written from the importing side: `boundaries` in `packages/app` can forbid `package:data/`. **Proposal:** no repository-level config until a rule needs one.
5. **Generated suffixes in config.** **Proposal:** a `generated` key with suffix globs that replaces the default list when present, as `exclude` does for files.
6. **A cycle is one finding or many.** **Proposal:** one finding per cycle, at the import that closes it in the cycle's first file by path, with the other files in the message. The id then changes only when that import does.

## Out of scope

- Unused declarations, duplication and complexity. They need more than parsing or already exist elsewhere, and come in through plugins ([#75](https://github.com/marcossevilla/vaixell/issues/75)).
- Annotations that make a library an entry point, such as `@pragma('vm:entry-point')`.
- Presets for `boundaries`, the `audit` command and new report formats. They have their own tickets on the map.
- Fixing what a rule reports.
- Implementing this spec.
