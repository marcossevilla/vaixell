# static-method

Don't declare static methods, getters or setters.

**Default:** error · **Preset:** `recommended`

## Details

Static members are global functions in disguise: callers depend on them
directly, so they can't be mocked or replaced. This rule reports public and
private static methods, getters and setters in classes, mixins, enums,
extensions and extension types.

Put the behavior on the type it works on, as an instance member, or in an
extension when you don't own the type. When callers need to swap it out in
tests, put it in a class passed through a constructor. Don't keep the
member in a class only to call it on a throwaway instance, as in
`const DateUtils().isWeekend(date)`: that call can't be swapped out either,
and [`throwaway-instance`](throwaway-instance.md) reports it.

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
extension Weekend on DateTime {
  static const int daysPerWeek = 7;

  bool get isWeekend => weekday > 5;
}
```

## Usage

```yaml
vaixell:
  rules:
    static-method: warning # or off
```
