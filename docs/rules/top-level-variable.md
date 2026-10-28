# top-level-variable

Don't declare top-level variables or constants.

**Default:** error · **Preset:** `recommended`

## Details

Top-level variables are global state, and top-level constants scatter
configuration across files. Both apply to `final`, `late` and `const`
declarations. Move them into the class that owns them.

**BAD:**

```dart
const defaultTimeout = Duration(seconds: 30);

final cache = <String, User>{};
```

**GOOD:**

```dart
class ApiClient {
  static const Duration defaultTimeout = Duration(seconds: 30);
}

class UserCache {
  final Map<String, User> _users = {};
}
```

## Usage

```yaml
vaixell:
  rules:
    top-level-variable: warning # or off
```
