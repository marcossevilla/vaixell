# extension-declaration

Don't declare extensions on a type that the same file declares.

**Default:** error · **Preset:** `recommended`

## Details

Extensions are for adding members to types you don't own, such as `String`
or a type from another package. When you own the type, an extension splits
its behavior in two: readers have to find the extension to know what the
type can do, and the extension's members can't be overridden or mocked. Add
the members to the type itself instead.

This rule reports named and unnamed extensions whose `on` type is a class,
mixin, enum or extension type declared in the same file. Extensions on other
types are allowed, and so are extension types: they declare a type of their
own, often a zero-cost wrapper such as `UserId` over a `String`.

vaixell checks one file at a time without resolving types, so it can't tell
that an extension's type is declared in another file of the same package. An
extension on an import with a prefix, as in `on core.String`, is never
reported.

**BAD:**

```dart
class User {
  const User(this.name);

  final String name;
}

extension UserX on User {
  String get initials => name[0];
}
```

**GOOD:**

```dart
class User {
  const User(this.name);

  final String name;

  String get initials => name[0];
}

extension StringX on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}

extension type const UserId(String value) {}
```

## Usage

```yaml
vaixell:
  rules:
    extension-declaration: warning # or off
```
