# top-level-function

Don't declare top-level functions, getters or setters.

**Default:** error · **Preset:** `recommended`

## Details

Top-level functions can't be mocked or swapped out in tests, and they grow
into grab bags of unrelated helpers. Put behavior where its data lives:

- **On the type it works on**, as an instance member. Use an extension when
  you don't own the type.
- **In a dependency**, a class passed through a constructor, when callers
  need to swap it out in tests.

Don't move a function into a class only to call it on a throwaway instance,
as in `const PriceFormatter().format(cents)`. That call can't be swapped out
any more than the function could, and
[`throwaway-instance`](throwaway-instance.md) reports it.

A top-level `main` function is allowed, because apps and scripts need an
entrypoint.

**BAD:**

```dart
String formatPrice(int cents) => '\$${cents / 100}';

String get appName => 'Vaixell';
```

**GOOD:**

```dart
extension type const Price(int cents) {
  String format() => '\$${cents / 100}';
}

class Checkout {
  const Checkout({required this.clock});

  final Clock clock;

  bool get isOpen => clock.now().hour < 22;
}

void main() {}
```

## Usage

```yaml
vaixell:
  rules:
    top-level-function: warning # or off
```
