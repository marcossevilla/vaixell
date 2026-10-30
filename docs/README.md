# Rules

vaixell checks Dart files by parsing them, without resolving types or running
`pub get`. Every rule below is part of the `recommended` preset, which runs
when a package has no `vaixell:` config.

Files with a generated suffix, such as `.g.dart`, `.freezed.dart` or
`.mocks.dart`, are never checked.

| Rule                                                      | Default | Description                                            |
| --------------------------------------------------------- | ------- | ------------------------------------------------------ |
| [`parse-error`](rules/parse-error.md)                     | error   | Files must parse without syntax errors.                |
| [`top-level-function`](rules/top-level-function.md)       | error   | Don't declare top-level functions, getters or setters. |
| [`top-level-variable`](rules/top-level-variable.md)       | error   | Don't declare top-level variables or constants.        |
| [`extension-declaration`](rules/extension-declaration.md) | error   | Don't declare extensions or extension types.           |
| [`static-method`](rules/static-method.md)                 | error   | Don't declare static methods, getters or setters.      |
| [`raw-json`](rules/raw-json.md)                           | error   | Keep raw JSON handling inside model classes.           |

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
- `rules`: a map of rule ids to `off`, `warning` or `error`. Errors fail the
  run, warnings are only reported.
- `exclude`: globs, relative to the package, for files that aren't checked.

Unknown keys, rules and presets are errors. `parse-error` can't be turned off.
