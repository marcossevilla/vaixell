# Implementation Plan: theseus phase 2

Source of intent: `docs/intent/theseus.md`. Phase 1 plan: `tasks/plan.md`.

## Overview

Phase 1 (Tasks 1–10) builds the CLI: the six v1 rules, config, full, diff
and baseline modes, workspace discovery, and the `text`, `json` and
`github` output formats. Phase 2 takes that CLI to a release and into CI:
a composite GitHub Action, a sticky PR comment, the self-check, the README
and pub.dev publishing. After the release, it adds per-rule excludes.

Task numbers continue from phase 1, so existing references to Tasks 11–14
still hold.

## Starting Point

Phase 2 assumes Checkpoint D in `tasks/plan.md` is done:

- `--format=json` prints a versioned document (`Report.toJson`).
- `--format=github` prints `::error`/`::warning` annotations and appends a
  markdown summary to `$GITHUB_STEP_SUMMARY`.
- Exit codes are final: `0` clean, `1` new errors, `64` usage, `70` git or
  internal failure, `78` config.

## Architecture Decisions

- **The action is thin.** `action.yml` at the repo root (so users write
  `uses: marcossevilla/theseus@v1`) is a composite action modeled on
  analytica's `packages/cognitive_complexity/action.yml`. It finds the PR
  base, fetches it, runs the CLI and returns the CLI's exit code. All logic
  stays in the CLI.
- **Inputs never reach the shell unquoted.** Every input goes through `env:`
  and is never interpolated into `run:` scripts.
- **Sticky PR comment.** `--comment-output=<file>` writes a markdown comment
  with a hidden marker and a table with Rule, File:Line and Message columns
  for the new violations. The action creates or updates the comment with
  `gh`, like analytica does. When a later run is clean, it changes the
  comment to a resolved status. If the run crashed, it leaves the comment
  alone. The rows are capped so the comment stays under GitHub's
  65536-character limit, and the step summary always has the full table.
- **Theseus passes its own check in CI.** `dart run bin/theseus.dart` runs
  on this repo with no baseline. Phase 1 already keeps it clean.
- **Per-rule excludes come after the release.** A rule entry in `rules:` can
  take `{severity, exclude}` next to the plain `rule: severity` form. The
  top-level `exclude:` keeps applying to every rule.

## Dependency Graph

```
Phase 1 (Tasks 1–10, Checkpoint D)
  ├── Composite action (Task 11)
  │     └── Sticky PR comment (Task 12)
  │           └── Self-check in CI + README + publish (Task 13)
  │                 └── Checkpoint E: v1 release
  └── Per-rule excludes (Task 14, needs only the phase 1 config)
```

## Task List

### Phase 5: The action and the release
- [ ] Task 11: Composite GitHub Action
- [ ] Task 12: Sticky PR comment with a table of failing rules
- [ ] Task 13: Self-check, README and publish readiness

### Checkpoint E: v1 release

### Phase 6: After v1
- [ ] Task 14: Per-rule `exclude:` globs

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

## Checkpoint E: v1 release
- [ ] All the success criteria in `docs/intent/theseus.md` are met:
  - It runs with no config on an unfamiliar repo and gives useful output.
  - PRs fail only on new violations.
  - Theseus passes its own check.
- [ ] Human approval to tag and publish.

---

## Task 14: Per-rule `exclude:` globs

**Description:** Let a rule entry in `rules:` take a map with a severity and
its own `exclude:` globs, next to the current `rule: severity` form. This
covers code that's correct by intent but can't be recognized without
types, such as the list-decoding pattern in API clients that `raw-json`
still flags.

```yaml
theseus:
  rules:
    top-level-function: warning
    raw-json:
      severity: error
      exclude:
        - "**/*_client.dart"
```

**Acceptance criteria:**
- [ ] Both forms are accepted. A rule's globs skip that rule only, while
      the top-level `exclude:` still skips every rule.
- [ ] Unknown keys in the map form, a missing `severity`, or invalid globs
      exit `78` with a `file:line:col` message.
- [ ] `parse-error` can't take per-rule excludes, so syntax errors are
      always reported.
- [ ] On `marcossevilla/compass_app`, one per-rule glob clears the 12
      remaining `raw-json` findings.

**Verification:**
- [ ] The standard checks pass.
- [ ] Table-driven config tests cover both forms and the invalid cases.

**Dependencies:** Task 3. It needs nothing else from phases 1 or 2, so it
can move ahead of the release if `raw-json` noise blocks adoption.

**Files likely touched:** `lib/src/config/{config,config_loader}.dart`,
`lib/src/engine/engine.dart`, `test/config/*`, `README.md`

**Estimated scope:** S

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| The action runs `dart run theseus_cli@<version>`, which needs the package on pub.dev, but publishing is Task 13 | High | The self-test workflow in Task 11 runs the action from this checkout (`dart run bin/theseus.dart`) or a git descriptor (`dart run 'theseus_cli@{git: ...}'`). Switch the action's default to the pub.dev version when Task 13 publishes. |
| Shallow `actions/checkout` clones don't have the PR base, so `--git-diff` exits `70` | High | The action fetches the base ref with enough depth to find the merge-base, like analytica. The CLI already explains a missing ref. |
| A `gh` API failure (permissions, rate limits) hides the CLI's result | Med | The comment step runs after the CLI step, never changes the exit code, and the README documents `pull-requests: write`. |
| The PR comment goes over GitHub's 65536-character limit | Med | `--max-comment-rows` caps the table and points to the step summary, which always has the full table. |
| `dart run theseus_cli@` behaves differently across SDK versions | Med | The SDK lower bound is 3.13. Test the action with `dart-lang/setup-dart` on stable and the lower bound. |

## Open Questions

- How should the action pick the CLI version before and after the first
  publish? See the first risk.
