# top-level-function

Don't declare top-level functions, getters or setters.

**Default:** error · **Preset:** `recommended`

## Details

Top-level functions can't be mocked or swapped out in tests, and they grow
into grab bags of unrelated helpers. Put behavior in a class instead.

A top-level `main` function is allowed, because apps and scripts need an
entrypoint.

**BAD:**

```dart
String formatPrice(int cents) => '\$${cents / 100}';

String get appName => 'Vaixell';
```

**GOOD:**

```dart
class PriceFormatter {
  const PriceFormatter();

  String format(int cents) => '\$${cents / 100}';
}

void main() {}
```

## Usage

```yaml
vaixell:
  rules:
    top-level-function: warning # or off
```
