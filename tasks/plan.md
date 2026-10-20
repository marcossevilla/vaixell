# Implementation Plan: theseus v1

Source of intent: `docs/intent/theseus.md`.

## Overview

`theseus` is a Dart CLI, published to pub.dev as `theseus_cli` and run with
`dart run theseus_cli@`, that checks architecture rules in any Dart or Flutter repo. It parses source
without type resolution and needs no `pub get` in the target repo. It runs in
two modes: a full-project run with an optional baseline, and a diff run
(`--git-diff=<ref>`) that reports new and fixed violation ids. Config lives
under a `theseus:` key in `analysis_options.yaml`. A thin composite GitHub
Action, modeled on analytica's `packages/cognitive_complexity/action.yml`,
wraps the CLI and finds the PR base on its own.

## Architecture Decisions

- **Name and location.** The pub package is `theseus_cli` (the name `theseus`
  is taken by an abandoned maze library). The pubspec declares two
  executables, `theseus_cli` (so that `dart run theseus_cli@` works) and
  `theseus`, both pointing at `bin/theseus.dart`. The library import is
  `package:theseus_cli/theseus_cli.dart`, and the repo is
  `github.com/marcossevilla/theseus`.
- **Single package at the repo root.** `bin/theseus.dart`, `lib/theseus_cli.dart`
  (public library API, so teams can depend on it instead of using plugins) and
  `lib/src/**`, with `action.yml` at the root so users can write
  `uses: marcossevilla/theseus@v1`. No workspace is needed for v1.
- **Unresolved AST only.** Use `package:analyzer`'s `parseString` on file
  contents. Syntax errors become `parse-error` violations, and the run doesn't
  crash. This is the "no pub get, no type resolution" constraint.
- **A `SourceTree` abstraction is the core seam.** The engine reads files
  through an interface with two implementations:
  `FileSystemSourceTree` (the working tree) and `GitSourceTree` (a git ref,
  read with `git ls-tree -r` and `git cat-file --batch`). Diff mode runs the
  same engine against both trees, so it needs no worktree checkout or stash
  and leaves nothing on disk. Discovery and config loading also go through
  `SourceTree`.
- **Violation ids are stable and don't include line numbers.** The format is
  `<rule>:<package-relative path>:<symbol path>`, with `#n` added when the
  same id appears more than once in a file. Examples:
  `top-level-function:lib/src/foo.dart:parse` and
  `static-method:lib/a.dart:Foo.bar`. Line and column are kept for reporting
  but aren't part of the identity. Diff mode and the baseline compare id
  sets, which is why the ids have to be stable.
- **Diff mode uses the head config for both sides.** Turning a rule on in a PR
  doesn't make every existing violation "new". The base side is the
  merge-base of `<ref>` and `HEAD`.
- **Config parser.** It reads `theseus:` from the root `analysis_options.yaml`
  (and, in workspaces, the member's own file, where the nearest file wins and
  nothing is merged). It accepts `include: <preset>`, a list of presets, and
  `rules: {name: off|warning|error}`. It never follows the analyzer's
  top-level `include:`. Unknown keys, rules or severities are errors that
  report a file:line from `package:yaml` spans.
- **Presets are built in and versioned in code.** `recommended` is the default
  when no config exists, and it sets every v1 rule to `error`. A run with no
  config on an unfamiliar repo can exit 1 but still gives useful output. On
  PRs, the action uses diff mode, so only new violations fail. `parse-error`
  is always on and can't be set to `off`.
- **Scan scope is `lib/**.dart` only**, excluding generated files
  (`*.g.dart`, `*.freezed.dart`, and similar) and anything matched by the
  config's `exclude:` globs. The only exemption is a top-level `main` function,
  because Flutter apps can't avoid `lib/main.dart`.
- **Rules have no other exemptions.** `top-level-function` covers top-level
  getters and setters. `top-level-variable` covers `const` values.
  `static-method` covers private methods and static getters and setters.
  Static fields and factory constructors aren't methods, so that rule doesn't
  flag them.
- **`raw-json` makes code use model classes to (de)serialize JSON.** It flags:
  - `jsonDecode` / `jsonEncode` calls
  - `json.decode` / `json.encode` calls
  - `Map<String, dynamic>` type annotations

  It allows these inside `fromJson` constructors or methods and `toJson`
  methods, in files under `**/models/**`, and in generated files.
- **Rules are a sealed registry.** Each rule is a class with an `id`, a
  default severity and an AST visitor that emits violations. There is no
  plugin loading.
- **Reporters:** `text` (the default locally), `json` (with a versioned
  `schemaVersion`) and `github` (`::error`/`::warning` annotations plus a
  markdown table in `$GITHUB_STEP_SUMMARY`).
- **Sticky PR comment.** `--comment-output=<file>` writes a markdown comment
  with a hidden marker and a table with Rule, File:Line and Message columns for
  the new violations. The action creates or updates the comment with `gh`,
  like analytica does. When a later run is clean, it changes the comment to a
  resolved status. If the run crashed, it leaves the comment alone. The rows
  are capped so the comment stays under GitHub's 65536-character limit, and
  the step summary always has the full table.
- **Exit codes** follow `package:io` `ExitCode`, the same as analytica:
  - `0`: clean.
  - `1`: at least one error-severity violation. In diff or baseline mode, only
    *new* violations count.
  - `64`: usage error.
  - `78`: config error.
  - `70`: internal or git failure.
- **Theseus passes its own check.** Only `lib/` is scanned, so `bin/` can
  stay a thin `main`. Code in `lib/` has no top-level functions or variables,
  no extensions, no static methods and no raw JSON (the JSON reporter and the
  baseline use model classes with `toJson`/`fromJson`).
  Code is organized into classes from the first commit, and CI runs
  `dart run bin/theseus.dart` on the repo.
- **Do not depend on `package:analytica` (0.x) for v1.** Its shapes don't fit
  what theseus needs: analytica lists modified files, while theseus has to
  read the full tree at a ref. Its API is also built on top-level functions,
  which would fight the self-check. We borrow its patterns (discovery order,
  action script, GitHub emitters) and not its code.
- **Tooling:** `very_good_analysis`, `package:test` with `test_descriptor` and
  `test_process` for CLI end-to-end tests, and 100% line coverage enforced in
  CI.

## Dependency Graph

```
Scaffold (pubspec, lints, CI, CLI shell)
  └── Engine core: SourceTree(fs) → discovery(single pkg) → parse → rules → Violation(id) → text reporter → exit code
        ├── Config (analysis_options `theseus:`, presets, severities)
        │     └── Remaining rules (top-level-variable, extension, static-method, raw-json)
        ├── GitSourceTree → diff mode (new/fixed)
        │     └── Baseline (same id-set comparison)
        ├── Workspace / monorepo discovery (+ per-member config)
        └── Reporters: json, github
              └── Composite action (diff base auto-detect)
                    └── Self-check + README + publish dry-run
```

## Task List

Tasks are tracked in `tasks/todo.md`, which has the full acceptance criteria.

### Phase 1: Tracer bullet
- [ ] Task 1: Scaffold the package, lints, CI and CLI shell
- [ ] Task 2: End-to-end full run with `parse-error` and `top-level-function`

### Checkpoint A: one rule works end to end on a single package

### Phase 2: Config and the risky core (diff mode)
- [ ] Task 3: `theseus:` config in `analysis_options.yaml`
- [ ] Task 4: `GitSourceTree` and `--git-diff` mode
- [ ] Task 5: Baseline (`--baseline`, `--write-baseline`)

### Checkpoint B: config, diff and baseline modes all work

### Phase 3: Rule set and discovery
- [ ] Task 6: Rules `top-level-variable`, `extension-declaration` and `static-method`
- [ ] Task 7: Rule `raw-json`
- [ ] Task 8: Workspace and monorepo auto-discovery

### Checkpoint C: v1 rule set runs on real repos

### Phase 4: Output, the action and the release
- [ ] Task 9: JSON reporter
- [ ] Task 10: GitHub reporter (annotations and step summary)
- [ ] Task 11: Composite GitHub Action
- [ ] Task 12: Sticky PR comment with a table of failing rules
- [ ] Task 13: Self-check, README and publish readiness

### Checkpoint D: ready to release v1

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Ids shift on harmless edits (renames, reorders), so diff mode reports noise | High | Ids leave out line numbers and use the symbol path. Add tests that move code around and check the ids stay the same. Use the `#n` suffix only for true duplicates. |
| Reading git trees is slow or fragile in big repos or shallow CI clones | High | Use `cat-file --batch`, a single process for each ref. The action fetches the base ref (like analytica). Report a clear exit-70 error when the ref can't be reached. Do this early, in Task 4. |
| `raw-json` causes false positives without types (for example, `Map<String, dynamic>` used for non-JSON data) | Med | Users can turn it off or exclude paths with globs. Record the false-positive counts from sample repos in Task 7 and revisit the allowed contexts if they're noisy. |
| The self-check forces awkward code style (no statics or top-level functions) | Med | Design for it from Task 1. Exempt `main`. Revisit the defaults if the restrictions hurt readability. |
| `dart run theseus_cli@` behaves differently across SDK versions | Med | Pin the SDK lower bound to one that supports it. Test the action with `dart-lang/setup-dart`, using both stable and the lower bound. |
| Generated files (`*.g.dart`, `*.freezed.dart`) flood the results | Med | Exclude them by default and add an `exclude:` globs key to the config. |

## Resolved Questions

- **Default severity:** every rule in `recommended` is `error`.
- **`raw-json`:** it makes code use model classes to (de)serialize JSON, as
  described in the Architecture Decisions.
- **Scope:** `lib/` only.
- **Exemptions:** none, apart from `main`.
- **PR feedback:** a sticky PR comment with a table of rule, file and line,
  plus annotations and the step summary.
- **Package and repo:** `theseus_cli` on pub.dev, `marcossevilla/theseus`
  on GitHub.

## Open Questions

None.
