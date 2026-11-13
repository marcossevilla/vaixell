# Rules

vaixell checks Dart files by parsing them, without resolving types or running
`pub get`. The `recommended` preset, which runs when a package has no
`vaixell:` config, enables every rule below at its default severity.

Files with a generated suffix, such as `.g.dart`, `.freezed.dart` or
`.mocks.dart`, are never checked.

| Rule                                                      | Default | Description                                            |
| --------------------------------------------------------- | ------- | ------------------------------------------------------ |
| [`parse-error`](rules/parse-error.md)                     | error   | Files must parse without syntax errors.                |
| [`top-level-function`](rules/top-level-function.md)       | error   | Don't declare top-level functions, getters or setters. |
| [`top-level-variable`](rules/top-level-variable.md)       | error   | Don't declare top-level variables or constants.        |
| [`extension-declaration`](rules/extension-declaration.md) | error   | Don't extend a type that the same file declares.       |
| [`static-method`](rules/static-method.md)                 | error   | Don't declare static methods, getters or setters.      |
| [`throwaway-instance`](rules/throwaway-instance.md)       | warning | Don't create an instance only to call a method on it.  |
| [`raw-json`](rules/raw-json.md)                           | error   | Keep raw JSON handling inside model classes.           |
| [`generated-json`](rules/generated-json.md)               | warning | Use json_serializable for `fromJson` and `toJson`.     |
| [`await-receiver`](rules/await-receiver.md)               | warning | Name an awaited value before using it.                 |

## Configuration

Configure rules under a `vaixell:` key in a package's `analysis_options.yaml`:

```yaml
vaixell:
  include: recommended
  rules:
    static-method: warning
    raw-json: off
  exclude:
    - lib/legacy/**
```

- `include`: a preset name, or a list of them. Defaults to `recommended`.
- `rules`: a map of rule ids to `off`, `info`, `warning` or `error`. Errors
  fail the run, and warnings are only reported unless `vaixell check` runs
  with `--fatal-warnings`. Info is only reported, even with
  `--fatal-warnings`, for rules you want to observe without enforcing them.

  Rules that take options use the long form, with the severity next to the
  options. Without `severity`, the rule is on at its default severity:

  ```yaml
  vaixell:
    rules:
      static-method: warning # short form
      some-rule: # long form
        severity: error
        some-option: [a, b]
  ```

  Options are only valid for rules that take them; anything else is an
  error at its line.
- `exclude`: globs, relative to the package, for files that aren't checked.

Unknown keys, rules and presets are errors. `parse-error` can't be turned off.

## Baselines

To adopt a rule in an existing repository without fixing every finding at
once, write a baseline and check against it. Findings in the baseline are
hidden, so only new ones are reported:

```sh
vaixell check --write-baseline=vaixell_baseline.json
vaixell check --baseline=vaixell_baseline.json
```

With `--git-diff` or `--baseline`, only new violations fail the run, and
`--fatal-warnings` applies only to them.
