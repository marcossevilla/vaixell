# static-method

Don't declare static methods, getters or setters.

**Default:** error · **Preset:** `recommended`

## Details

Static members are global functions in disguise: callers depend on them
directly, so they can't be mocked or replaced. This rule reports public and
private static methods, getters and setters in classes, mixins, enums,
extensions and extension types. Use an instance member instead.

Static fields and factory constructors aren't methods, so they aren't
reported.

**BAD:**

```dart
class DateUtils {
  static bool isWeekend(DateTime date) => date.weekday > 5;
}
```

**GOOD:**

```dart
class DateUtils {
  const DateUtils();

  static const int daysPerWeek = 7;

  bool isWeekend(DateTime date) => date.weekday > 5;
}
```

## Usage

```yaml
vaixell:
  rules:
    static-method: warning # or off
```
