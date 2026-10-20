# Intent: theseus

Confirmed statement of intent for `theseus`, an architecture checker for Dart
and Flutter repositories.

- **Outcome:** `theseus` is a published Dart CLI (`dart run theseus_cli@`) that
  checks architecture rules in any Dart or Flutter repo. A thin composite
  GitHub Action wraps it, built the same way as
  [analytica](https://github.com/kevmoo/analytica.dart)'s.
- **User:** Dart and Flutter teams who want to block architecture regressions
  on PRs and local runs. It doesn't give feedback in the editor.
- **Modes:**
  - Full-project run, with an optional baseline.
  - Diff run (`--git-diff=<ref>`), which checks the base and the head and
    reports new and fixed violation ids. The action detects the PR base on its
    own.
- **Config:** a `theseus:` key in `analysis_options.yaml`, written the way
  people already write lint config: built-in presets by name
  (`include: recommended`) and a `rules:` map with `off`, `warning` or
  `error`. It doesn't follow the analyzer's `include:` chains, so the target
  repo needs no `pub get`. Unknown keys are errors.
- **v1 scope:**
  - Rules: `parse-error`, `top-level-function`, `top-level-variable`,
    `extension-declaration`, `static-method`, `raw-json`.
  - Workspace and monorepo auto-discovery.
  - Output: text, json and github (annotations and step summary).
  - Exit codes and the action.
- **Success:**
  - On an unfamiliar repo, it runs with no config and gives useful output.
  - PRs fail only on new violations.
  - Theseus passes its own check.
- **Next (named as work in progress in the v1 release):** layout, layers, the
  feature graph and import rules. A `theseus.yaml` fallback only if the v2
  config gets too big.
- **Out of scope:** CopilotKit and anything taken from it, the analyzer plugin
  and IDE integration, custom rule plugins and the generated runner (teams can
  depend on the library instead), following foreign `include:` presets for
  now, auto-fix, and type resolution.
