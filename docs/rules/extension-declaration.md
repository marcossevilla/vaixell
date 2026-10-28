# extension-declaration

Don't declare extensions or extension types.

**Default:** error · **Preset:** `recommended`

## Details

Extensions add members to types from anywhere in a codebase, which makes it
hard to know where behavior lives, and their members can't be mocked. This
rule reports named extensions, unnamed extensions and extension types. Use a
class instead.

**BAD:**

```dart
extension StringX on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}

extension type UserId(String value) {}
```

**GOOD:**

```dart
class Capitalizer {
  const Capitalizer();

  String capitalize(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}

class UserId {
  const UserId(this.value);

  final String value;
}
```

## Usage

```yaml
vaixell:
  rules:
    extension-declaration: warning # or off
```
