# theseus v1: Tasks

See `tasks/plan.md` for the design decisions. The standard verification for
every task is:

- `dart format --set-exit-if-changed .`
- `dart analyze --fatal-infos --fatal-warnings bin lib test`
- `very_good dart test --coverage --min-coverage 100 --report-on lib`, the
  same check `very_good_workflows` runs in CI

---

## Task 1: Scaffold the package, lints, CI and CLI shell

**Description:** Create the git repo (remote `marcossevilla/theseus`), the `theseus_cli`
package at the root (executables `theseus_cli` and `theseus`, both pointing at
`bin/theseus.dart`), the
lints and the CI. Add a CLI shell that parses arguments (`--help`,
`--version`, `--format`, `--git-diff`, `--baseline`, `--write-baseline`,
positional paths) and exits with the right codes for usage errors. It doesn't
run any analysis yet.

**Acceptance criteria:**
- [x] `dart run bin/theseus.dart --help` prints usage. `--version` prints the
      version from the pubspec, using a generated or tested constant.
- [x] An unknown flag exits with `64` and prints usage to stderr.
- [x] CI workflow (`.github/workflows/ci.yaml`) runs format, analyze, test and
      the coverage gate on stable and on the SDK lower bound.

**Verification:**
- [x] The standard checks pass.
- [x] `test/cli_test.dart` uses `test_process` to cover the help, version and
      unknown-flag cases.

**Dependencies:** None

**Files likely touched:** `pubspec.yaml`, `analysis_options.yaml`,
`bin/theseus.dart`, `lib/theseus_cli.dart`, `lib/src/cli/theseus_command.dart`,
`test/cli_test.dart`, `.github/workflows/ci.yaml`, `.gitignore`

**Estimated scope:** M

---

## Task 2: End-to-end full run with `parse-error` and `top-level-function`

**Description:** Add the tracer bullet. `FileSystemSourceTree` provides the
files, single-package discovery finds `lib/**.dart` (excluding generated
files), `parseString` parses them, and two rules (`parse-error` and
`top-level-function`) produce `Violation`s with stable ids. The text reporter
prints them, and the exit code reflects the result.

**Acceptance criteria:**
- [x] A fixture package with one top-level function and one broken file
      reports exactly 2 violations, with the ids
      `top-level-function:lib/a.dart:foo` and `parse-error:lib/b.dart`.
- [x] Moving `foo` to a different line, or adding code above it, doesn't
      change its id.
- [x] Exit code: `1` when there are violations and `0` when the package is
      clean. Only `lib/` is scanned, and a top-level `main` in `lib/` (for
      example `lib/main.dart`) isn't flagged. Top-level getters and setters
      are flagged.

**Verification:**
- [x] The standard checks pass.
- [x] Unit tests cover the rules and the id builder, and an end-to-end
      `test_process` test runs on a `test_descriptor` fixture.

**Dependencies:** Task 1

**Files likely touched:** `lib/src/source/source_tree.dart`,
`lib/src/engine/engine.dart`, `lib/src/engine/violation.dart`,
`lib/src/rules/{rule,parse_error,top_level_function}.dart`,
`lib/src/report/text_reporter.dart`, tests

**Estimated scope:** M

---

## Checkpoint A
- [x] All tests pass and coverage is 100%.
- [x] `dart run bin/theseus.dart` on a scratch Flutter app gives readable
      output.
- [x] Review the id format with a human before building diff and baseline
      on top of it.

---

## Task 3: `theseus:` config in `analysis_options.yaml`

**Description:** Load the `theseus:` key from `analysis_options.yaml` through
`SourceTree`. It supports `include: <preset | [presets]>`,
`rules: {id: off|warning|error}` and `exclude: [globs]`. Add the
`recommended` preset, which sets every rule to `error` and is the default when
there's no config. The
analyzer's top-level `include:` is never followed.

**Acceptance criteria:**
- [x] With no file or no `theseus:` key, the run uses `recommended`.
      `rules: {top-level-function: off}` turns that rule off, and `warning`
      makes it exit `0`.
- [x] Unknown keys, rules, presets or severities exit with `78` and a
      `file:line:col` message. Setting `parse-error: off` is also rejected.
- [x] A top-level analyzer `include: package:foo/...` is ignored, with no
      error and no file read.

**Verification:**
- [x] The standard checks pass.
- [x] A table-driven config test covers the valid and invalid YAML cases.

**Dependencies:** Task 2

**Files likely touched:** `lib/src/config/{config,config_loader,presets}.dart`,
`lib/src/engine/engine.dart`, `test/config/*`

**Estimated scope:** M

---

## Task 4: `GitSourceTree` and `--git-diff` mode

**Description:** Add a `SourceTree` backed by a git ref (`ls-tree` and
`cat-file --batch`). `--git-diff=<ref>` resolves the merge-base with `HEAD`
and runs the engine on base and head, using the head config for both. It
then reports the new and fixed ids. Only new error-severity violations fail
the run.

**Acceptance criteria:**
- [x] In a temp git repo fixture, a branch that adds one top-level function
      and removes another reports 1 new and 1 fixed. It exits `1`, or `0` if
      it only fixed violations.
- [x] Uncommitted working-tree changes count as head.
- [x] A ref that can't be reached, or a directory that isn't a git repo,
      exits `70` with a clear message.

**Verification:**
- [x] The standard checks pass.
- [x] Integration tests create real temp repos with `git init`, `commit` and
      `checkout`.

**Dependencies:** Tasks 2 and 3

**Files likely touched:** `lib/src/source/git_source_tree.dart`,
`lib/src/git/git_runner.dart`, `lib/src/engine/diff_result.dart`,
`lib/src/cli/theseus_command.dart`, `test/git/*`

**Estimated scope:** M

---

## Task 5: Baseline (`--baseline`, `--write-baseline`)

**Description:** `--write-baseline=<file>` writes the current sorted set of
violation ids as JSON. `--baseline=<file>` suppresses the ids in that set,
reports only new ones, and lists stale (fixed) entries.

**Acceptance criteria:**
- [ ] Writing a baseline and then running with it exits `0` and reports
      nothing new. Adding a violation exits `1`.
- [ ] The baseline file is deterministic (sorted, includes
      `schemaVersion`), so it gives stable git diffs.
- [ ] A missing or malformed baseline exits `78`. `--baseline` can be
      combined with `--git-diff`.

**Verification:**
- [ ] The standard checks pass.

**Dependencies:** Task 4 (shares the id-set comparison)

**Files likely touched:** `lib/src/baseline/baseline.dart`,
`lib/src/cli/theseus_command.dart`, `test/baseline_test.dart`

**Estimated scope:** S

---

## Checkpoint B
- [ ] All tests pass and coverage is 100%.
- [ ] Manual check: on a real repo, run with `--git-diff=origin/main` and then
      with a baseline. The output matches what you expect.
- [ ] Human review before expanding the rule set.

---

## Task 6: Rules `top-level-variable`, `extension-declaration` and `static-method`

**Description:** Add the three rules, which are syntactic only. Each one
registers in the rule registry and the `recommended` preset, and builds its
id from the symbol path. None of them has exemptions.

**Acceptance criteria:**
- [ ] Each rule flags its positive fixtures and ignores its negative ones:
  - `top-level-variable`: covers `final`, `var`, `const` and `late`.
  - `extension-declaration`: covers named and unnamed extensions, and
    extension types.
  - `static-method`: covers public and private methods and static
    getters and setters, in classes, mixins, enums, extensions and extension
    types. Static fields and factory constructors aren't methods, so they
    aren't flagged.
- [ ] Ids are `<rule>:<path>:<Container>.<member>`, or `<unnamed>` for
      unnamed extensions, with `#n` added for duplicates.

**Verification:**
- [ ] The standard checks pass.

**Dependencies:** Task 3

**Files likely touched:**
`lib/src/rules/{top_level_variable,extension_declaration,static_method}.dart`,
`lib/src/rules/registry.dart`, `lib/src/config/presets.dart`,
`test/rules/*`

**Estimated scope:** M

---

## Task 7: Rule `raw-json`

**Description:** Add a syntactic rule that makes code (de)serialize JSON
through model classes instead of handling raw JSON.

**Acceptance criteria:**
- [ ] It flags `jsonDecode` / `jsonEncode` calls, `json.decode` /
      `json.encode` calls and `Map<String, dynamic>` type annotations
      outside the allowed contexts.
- [ ] It doesn't flag code inside `fromJson` constructors or methods,
      `toJson` methods, files under `**/models/**`, or generated files.
- [ ] Running it on 2 public sample repos produces a false-positive count
      that's recorded in the PR description.

**Verification:**
- [ ] The standard checks pass.

**Dependencies:** Task 3

**Files likely touched:** `lib/src/rules/raw_json.dart`,
`lib/src/rules/registry.dart`, `test/rules/raw_json_test.dart`

**Estimated scope:** S

---

## Task 8: Workspace and monorepo auto-discovery

**Description:** Discover the packages through `SourceTree`, in this order:
1. The root `pubspec.yaml` `workspace:` members, plus the root package.
2. A single package.
3. `packages/*`, `pkgs/*` and immediate children that have a `pubspec.yaml`.

Ids use paths relative to the repo root. Each member uses the nearest
`analysis_options.yaml` with a `theseus:` key, with no merging. Positional
paths override discovery.

**Acceptance criteria:**
- [ ] Fixtures for a workspace, a monorepo without a workspace and a single
      package each scan the expected `lib/` directories.
- [ ] A member's own `theseus:` config overrides the root config for that
      member only.
- [ ] Discovery works the same on `GitSourceTree`, so diff mode works in
      monorepos.

**Verification:**
- [ ] The standard checks pass.

**Dependencies:** Tasks 3 and 4

**Files likely touched:** `lib/src/discovery/package_discovery.dart`,
`lib/src/config/config_loader.dart`, `lib/src/engine/engine.dart`,
`test/discovery/*`

**Estimated scope:** M

---

## Checkpoint C
- [ ] All tests pass and coverage is 100%.
- [ ] Manual check: run with no config on 2 or 3 unfamiliar public repos
      (one workspace, one Flutter app). The output is useful, with no crashes
      and no generated-file noise.
- [ ] Human review of the default severities and the rule exemptions.

---

## Task 9: JSON reporter

**Description:** `--format=json` emits one versioned document that includes:
- `schemaVersion`
- `mode` (`full`, `diff` or `baseline`)
- the violations, each with id, rule, severity, path, line, column and
  message
- for diff and baseline runs, `new` and `fixed`
- a summary with counts

**Acceptance criteria:**
- [ ] The output is valid JSON on stdout. Nothing else is written to stdout.
- [ ] Golden-file tests cover the full, diff and baseline modes.
- [ ] The schema is documented in the doc comments of the public model
      classes.

**Verification:**
- [ ] The standard checks pass.

**Dependencies:** Tasks 4 and 5

**Files likely touched:** `lib/src/report/json_reporter.dart`,
`lib/src/report/reporter.dart`, `test/report/json_reporter_test.dart`

**Estimated scope:** S

---

## Task 10: GitHub reporter (annotations and step summary)

**Description:** `--format=github` emits `::error`/`::warning file=,line=,col=`
annotations, which are only for new violations in diff or baseline mode. It
also appends a markdown summary (counts plus tables of new and fixed
violations) to `$GITHUB_STEP_SUMMARY` when that variable is set.

**Acceptance criteria:**
- [ ] Annotation messages escape `%`, `\r`, `\n`, `:` and `,` as the workflow
      command format requires.
- [ ] The summary file is appended to, not overwritten. Without the env var,
      no summary is written.
- [ ] The number of annotations is capped (GitHub limits them per step), and
      the summary says how many were left out.

**Verification:**
- [ ] The standard checks pass.

**Dependencies:** Task 9

**Files likely touched:** `lib/src/report/github_reporter.dart`,
`test/report/github_reporter_test.dart`

**Estimated scope:** S

---

## Task 11: Composite GitHub Action

**Description:** Add an `action.yml` at the root, modeled on analytica's.
- On `pull_request`, it detects the base (`origin/$GITHUB_BASE_REF`) and
  fetches it.
- It runs `dart run theseus_cli@<version> --format=github [--git-diff=...]`,
  passing through the user inputs.
- It returns the CLI's exit code.

**Acceptance criteria:**
- [ ] Inputs: `paths`, `diff-base` (an override), `baseline` and `format`
      (default `github`). Every input is passed to the shell through `env:`
      and is never interpolated.
- [ ] A self-test workflow runs the action against this repo on PRs and on
      push. Push runs do a full run, and PR runs do a diff run.
- [ ] It works with a shallow `actions/checkout`. The fetch step handles
      depth.

**Verification:**
- [ ] `actionlint` passes, and the self-test workflow is green on a test PR.

**Dependencies:** Task 10

**Files likely touched:** `action.yml`,
`.github/workflows/action_self_test.yaml`

**Estimated scope:** S

---

## Task 12: Sticky PR comment with a table of failing rules

**Description:** `--comment-output=<file>` writes a markdown comment with a
hidden marker (`<!-- theseus-comment-marker -->`), the counts of new and fixed
violations, and a table with Rule, File:Line and Message columns. The file:line
entries link to the head SHA. The action finds the marked comment with `gh`
and updates it, or creates one if it doesn't exist.

**Acceptance criteria:**
- [ ] When the run has new violations, the comment has one row per new
      violation, sorted by rule and then by file.
- [ ] `--max-comment-rows` caps the rows and adds a note that points to the
      step summary. When the run has no new violations, the CLI writes no
      file.
- [ ] The action posts or updates only on `pull_request` with `github`
      format. When a later run is clean (exit 0), it changes an existing
      comment to "resolved". If the run crashed, it leaves the comment alone.
      A failure in the `gh` API never hides the CLI's exit code.
- [ ] The action README documents the `pull-requests: write` permission it
      needs.

**Verification:**
- [ ] The standard checks pass, plus golden tests for the comment markdown.
- [ ] Manual check: on a test PR, the comment is created, updated and then
      changed to resolved.

**Dependencies:** Tasks 10 and 11

**Files likely touched:** `lib/src/report/pr_comment_writer.dart`,
`lib/src/cli/theseus_command.dart`, `action.yml`,
`test/report/pr_comment_writer_test.dart`

**Estimated scope:** M

---

## Task 13: Self-check, README and publish readiness

**Description:** Make theseus pass its own check and enforce it in CI. Write
the README with these sections:
- install and run
- the config reference
- the rules
- modes and exit codes
- action usage
- a "Work in progress" section for layout, layers, the feature graph and
  import rules

Also prepare the CHANGELOG and the pub.dev metadata.

**Acceptance criteria:**
- [ ] The CI step `dart run bin/theseus.dart` exits `0` on this repo, with
      no baseline.
- [ ] `dart pub publish --dry-run` has no warnings, and the `executables:`
      entry makes `dart run theseus_cli@` work.
- [ ] The README examples match the actual `--help` output. A test checks
      this.

**Verification:**
- [ ] The standard checks pass, the self-check is green and the publish dry
      run is clean.

**Dependencies:** Task 12

**Files likely touched:** `README.md`, `CHANGELOG.md`, `pubspec.yaml`,
`.github/workflows/ci.yaml`, `example/`

**Estimated scope:** M

---

## Checkpoint D: v1 release
- [ ] All the success criteria in `docs/intent/theseus.md` are met:
  - It runs with no config on an unfamiliar repo and gives useful output.
  - PRs fail only on new violations.
  - Theseus passes its own check.
- [ ] Human approval to tag and publish.
