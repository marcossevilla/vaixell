# Spec: config-declared plugins

**Status:** proposed, for approval in review.
**Map:** [#75](https://github.com/marcossevilla/vaixell/issues/75).
**Vocabulary:** [`GLOSSARY.md`](../../GLOSSARY.md), plus the terms in [Vocabulary](#vocabulary).
**Builds on:** [package rules](package-rules.md), for findings that carry a path, a line and a column.

## Goal

A repository opts in to rules that live outside vaixell from config alone, with the stock `vaixell` binary. The first plugin, `vaixell_analytica`, reports what [analytica.dart](https://github.com/kevmoo/analytica.dart) finds: dead code, duplication and complexity.

Constraints:

- **Opt-in from config.** No custom entry point and no second executable.
- **Nothing changes without plugins.** A repository that declares none starts no process, needs no network and stays parse-only.
- **Layers don't leak.** `vaixell` and `vaixell_cli` know the protocol, never a plugin. A plugin knows the protocol, never the CLI.
- **One kind of result.** A plugin's findings become violations with vaixell's ids, severities, baselines and reporters.
- **Packages, not commands.** Config names pub packages. It can't name a command to run.

## At a glance

```yaml
# analysis_options.yaml, at the repository root
vaixell:
  plugins:
    vaixell_analytica: ^0.1.0
  rules:
    dead-code: warning
    duplication:
      severity: info
      min-tokens: 40
```

Without the `plugins` entry, `dead-code` is an unknown rule, as today.

## Vocabulary

| Term        | Type         | Meaning                                                                                  |
| ----------- | ------------ | ---------------------------------------------------------------------------------------- |
| Plugin      | `Plugin`     | A pub package that vaixell runs as a separate process and that provides plugin rules.    |
| Plugin rule | `PluginRule` | A rule that a plugin provides. Config sees it as a rule entry; a plugin process runs it. |
| Protocol    | —            | The JSON messages vaixell and a plugin exchange.                                         |

## Config

### `plugins`

A map from package names to version constraints, under `vaixell:`.

- **Root only.** It's valid in the root `analysis_options.yaml`. In any other config file it's an error at its line, as the analyzer rejects its own `plugins` in nested files.
- **A constraint is required.** `any` and an empty value are errors, so a run can't silently pick up a new major version.
- **A path for development.** `my_plugin: {path: ../my_plugin}` runs a plugin from a directory, relative to the config file. It's how `vaixell_analytica` is tested in this repository.

### Plugin rules under `rules`

A plugin's rules are configured like any other, in any package's config: `id: severity`, or the long form with options.

- **Never recommended.** A plugin rule is on only for packages whose config names it. Declaring a plugin turns nothing on.
- **Options belong to the plugin.** vaixell passes them through and reports what the plugin rejects at the option's line and column.
- **Ids are shared.** A plugin rule whose id is taken by a built-in rule or another plugin is a config error that names both (see gap 1).

## How a run goes

1. **Load the root config.** With no `plugins`, nothing below happens.
2. **Start each plugin** and ask it to describe itself. Its rule ids join the injected ones, so unknown-id checks cover them.
3. **Load package configs** and run rules and package rules as today.
4. **Ask each plugin to check** the packages that enable at least one of its rules, in one request.
5. **Turn its findings into violations** and merge them with the rest, by the rules in [package rules](package-rules.md): same id format, same order, same ignore comments.
6. **Close the plugin's input**, which ends it.

A plugin runs once per `vaixell` run, whatever the number of packages.

### Starting a plugin

vaixell runs the `vaixell_plugin` executable of the package with `dart run`, in its remote-package form: `dart run <package>:vaixell_plugin@<descriptor>`. This is what lets a repository use a plugin that isn't in any `pubspec.yaml`.

- **Working directory:** the repository root.
- **Requirements:** `dart` on the path, and network access the first time a version is used.
- **A path plugin** runs `dart run` in the plugin's directory, which must be resolved.

The exact descriptor for a constraint, and what `dart run` caches between runs, are for the spike to pin down (see gap 2).

### Comparing with a base

Plugins read the files on disk, so they can't run on the base side of `--git-diff`, which vaixell reads from git.

- **Full runs** report plugin violations like any other.
- **With `--baseline`**, the baseline decides which are new.
- **With `--git-diff` alone**, plugin violations are listed but are never new, so they don't fail the run (see gap 4).

## The protocol

One JSON object per line: requests on the plugin's standard input, responses on its standard output, in order. Standard error is free text that vaixell shows with `--verbose`.

### `describe`

```json
{ "protocol": 1, "method": "describe" }
```

```json
{
  "protocol": 1,
  "rules": [
    {
      "id": "dead-code",
      "defaultSeverity": "warning",
      "docs": "https://pub.dev/packages/vaixell_analytica#dead-code"
    }
  ]
}
```

- `protocol` is the version each side speaks. On a mismatch vaixell fails and says which side to update.
- `defaultSeverity` is used when config only enables the rule.
- `docs` is optional, and becomes `Violation.docs`.

### `check`

```json
{
  "protocol": 1,
  "method": "check",
  "root": "/home/me/repo",
  "packages": [
    {
      "path": "packages/app",
      "name": "app",
      "exclude": ["lib/legacy/**"],
      "rules": { "dead-code": { "mode": "closed-app" } }
    }
  ]
}
```

```json
{
  "protocol": 1,
  "findings": [
    {
      "rule": "dead-code",
      "path": "packages/app/lib/src/user.dart",
      "line": 12,
      "column": 7,
      "message": "`User.copy` is never used. Delete it.",
      "symbol": "User.copy"
    }
  ],
  "optionErrors": [
    {
      "package": "packages/app",
      "rule": "dead-code",
      "key": ["mode"],
      "message": "must be `library` or `closed-app`"
    }
  ]
}
```

- `packages` lists only packages that enable one of the plugin's rules, and `rules` only those rules, each with its options without `severity`.
- `path`s are relative to `root`, in POSIX style, as vaixell reports them.
- `symbol` is what keeps a violation id stable when lines move. A plugin should always send one.
- `optionErrors` become `ConfigException`s at the position of `key` in that package's config.

### Failures

A plugin that can't start, exits with an error, answers with something that isn't valid, or reports a finding for a rule it didn't describe or a path outside the package, fails the run with a `PluginException` that names the plugin. The CLI maps it to an exit code as it does `GitException`: unavailable when the plugin couldn't start, a data error otherwise.

A run never reports a partial result.

## Trust

Declaring a plugin lets a repository's config make vaixell download and run code. That's the same trust as a dev dependency or an analyzer plugin, and it's why:

- config names packages with constraints, never commands;
- `plugins` is read from one file, the root config;
- `vaixell check --no-plugins` starts none.

With `--no-plugins`, rule ids that vaixell doesn't know are skipped with a note on standard error instead of failing, but only when the root config declares plugins. It's for checkouts you don't trust, such as a pull request from a fork.

## Writing a plugin

`package:vaixell/plugin.dart` is a third public library, beside `vaixell.dart` and `testing.dart`. It holds the protocol types and a helper, so a Dart plugin doesn't write JSON by hand.

```dart
// bin/vaixell_plugin.dart
import 'package:vaixell/plugin.dart';

Future<void> main() => const Plugin([DeadCodeRule()]).serve();
```

```dart
final class const DeadCodeRule() extends PluginRule {
  @override
  String get id => 'dead-code';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Future<List<PackageFinding>> check(PluginPackage package, OptionValue options) async {
    options.allowOnly({'mode'});
    // …
  }
}
```

- **`PluginPackage`** is the request's package: `root`, `path`, `name` and `excludes(path)`.
- **`OptionValue`** is the interface rules already use, backed by the request's JSON. A reader that throws becomes an `optionErrors` entry, so a plugin validates options the way a rule does.
- **`asInt()` and `asBool()`** join `OptionValue`'s readers. The rule authoring spec left them out until a rule needed them, and `min-tokens: 40` does.
- **`PackageFinding`** is the one from [package rules](package-rules.md).

Nothing requires a plugin to be written in Dart or to use this library. The protocol is the contract.

## Wiring

| Layer         | Change                                                                                                               |
| ------------- | -------------------------------------------------------------------------------------------------------------------- |
| `rules`       | `RuleEntry` gains a fifth, internal kind for a described plugin rule, so `RuleSet` and config treat it like the rest |
| `plugin`      | new: the protocol types, the `Plugin` helper, and `PluginRunner`, which starts plugins and speaks to them            |
| `config`      | reads `plugins` from the root config; passes plugin rule options through                                             |
| `check`       | describes plugins before loading package configs, runs them after the engine, merges their violations                |
| `vaixell_cli` | `--no-plugins` on `check`; maps `PluginException` to an exit code                                                    |

`Check` takes an optional `PluginRunner`, so tests replace it and other callers can turn plugins off.

## `vaixell_analytica`

A new package in this repository, released on its own like the other two.

| Rule          | Runs                                             | Options                                                                 | Symbol                 |
| ------------- | ------------------------------------------------ | ----------------------------------------------------------------------- | ---------------------- |
| `dead-code`   | `UndeadEngine` from `undead`                     | `mode`, `example-mode`, `test-support-patterns`, `ignore-name-patterns` | the declaration's name |
| `duplication` | `DedupeEngine` from `dedupe`                     | `min-tokens`, `min-lines`, `ignore-identifiers`                         | see gap 6              |
| `complexity`  | `ComplexityAnalyzer` from `cognitive_complexity` | `threshold`                                                             | the function's name    |

- **Dependencies:** `vaixell`, for `plugin.dart` only, and the three analytica packages. `undead` and `dedupe` are at 0.1, so their constraints are tight.
- **Not a dependency of anything.** `vaixell` and `vaixell_cli` never import it, and it never imports `vaixell_cli`.
- **analytica's own ignore comments** (`// undead:ignore`) keep working, since its engines read them. vaixell's ignore comments work too, on the violations.
- **`dead-code` needs resolved dependencies**, since `undead` resolves types. When a package isn't resolved, the rule fails with a message that says to run `dart pub get` there. It doesn't run it.

## Gaps for review

Each has a proposal; approving the spec approves them.

1. **Plain or prefixed rule ids.** `dead-code` is short, but two plugins can claim it, and `--no-plugins` can't tell whose an unknown id is. `vaixell_analytica/dead-code` solves both and is how the analyzer names plugin diagnostics. **Proposal:** plain ids, with a clash as a config error, because ids are typed in config and ignore comments far more often than plugins clash.
2. **What `dart run` gives us.** The spike has to answer: the descriptor for a version constraint, whether a second run needs the network, and what starting a plugin costs. **Proposal:** the protocol and the config don't depend on the answers; only `PluginRunner` does. If the cost is too high, `describe` is cached by package and version under `.dart_tool/vaixell/`.
3. **One process for both requests.** `describe` and `check` could be two short runs. **Proposal:** one process that answers both, so a run pays for one start.
4. **Plugin violations under `--git-diff`.** Never new, or always new? Always new would fail every pull request in a repository with existing dead code. **Proposal:** never new without a baseline, and the text report says how many were left out of the comparison.
5. **Where the helper lives.** In `vaixell`, a plugin depends on the whole library and its `analyzer` constraint. **Proposal:** start in `vaixell` as `plugin.dart`; move it to its own package if a plugin can't resolve.
6. **A stable symbol for a clone.** A clone has no name, and its lines move. **Proposal:** the name of the declaration each instance is in, with a qualifier from a hash of the normalized tokens, as in `ApiClient.getUser@clone-3f2a`. To be confirmed against what `dedupe` reports.
7. **Timeouts.** A plugin that hangs would hang the run. **Proposal:** none in the first version; `--verbose` shows which plugin is running.

## Out of scope

- Plugins that aren't pub packages, and commands in config.
- Loading plugin code into vaixell's process.
- Rules that read one file at a time through the protocol. A plugin checks packages.
- Fixes from plugins.
- A registry or discovery of plugins.
- Implementing this spec.
