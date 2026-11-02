# await-receiver

Name an awaited value before using it.

**Default:** warning · **Preset:** `recommended`

## Details

Dereferencing an `await` inside parentheses makes async code read inside out.
Assigning the awaited value to a local variable first keeps it readable top to
bottom. This rule reports an `await` used as the receiver of:

- A property access: `(await f).x`, `(await f)?.x`.
- A method call: `(await f).m()`, `(await f)?.m()`.
- An index: `(await f)[i]`, `(await f)?[i]`.
- A cascade: `(await f)..a()`, `(await f)?..a()`.
- A call: `(await f)()`.
- A null check: `(await f)!`, wherever it's written, including
  `final v = (await f)!;`. Like a member access, `!` acts on the awaited
  value, so it belongs on the named variable: `final v = await f;` then `v!`.
  A cast only states the type the value is named with, so
  `final v = await f as T;` is allowed.

Parentheses and `as` casts are looked through, so `((await f)).x` and
`((await f) as T).x` are reported too. Each `await` is reported once, at the
`await` keyword, so `(await f)!.x` is a single finding.

These are allowed:

- Initializers and assignments: `final v = await f;`, `v = await f;` and
  `final v = await f as T;`.
- A cast with no receiver: `(await f) as T`.
- Conditions and operands: `if (await f)`, `!await f`, `(await f) != null`.
- Arguments: `g(await f)`, `expect(await f, x)`.
- `return await f;` and `=> await f`.

There is no auto-fix. In a short-circuit expression such as
`a && (await f).x` or `a ?? (await f).x`, the `await` only runs when the left
side doesn't decide the result, so hoisting it into a variable would change
when it runs. Use a nested `if` instead of a plain variable there:

```dart
// Before: `isReady()` only runs when `enabled` is true.
if (enabled && (await isReady()).ok) {
  start();
}

// After
if (enabled) {
  final ready = await isReady();
  if (ready.ok) start();
}
```

**BAD:**

```dart
class ApiClient {
  Future<String> getUserName() async {
    return (await _getUser()).name;
  }

  Future<int> getCount() async => (await _getCount())!;
}
```

**GOOD:**

```dart
class ApiClient {
  Future<String> getUserName() async {
    final user = await _getUser();
    return user.name;
  }

  Future<int> getCount() async {
    final count = await _getCount();
    return count!;
  }
}
```

## Usage

```yaml
vaixell:
  rules:
    await-receiver: error # or off
```
