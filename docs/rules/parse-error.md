# parse-error

Files must parse without syntax errors.

**Default:** error · **Preset:** `recommended` · **Can be turned off:** no

## Details

The other rules skip files with syntax errors, so this rule makes sure those
files still fail the run. It reports the first syntax error in the file and
how many more there are.

**BAD:**

```dart
class User {
  final String name
}
```

**GOOD:**

```dart
class User {
  final String name;
}
```

## Usage

This rule is always on. It can be set to `warning`, but not to `off`:

```yaml
vaixell:
  rules:
    parse-error: warning
```
