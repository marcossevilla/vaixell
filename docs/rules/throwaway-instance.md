# throwaway-instance

Don't create an instance only to call a method on it.

**Default:** warning · **Preset:** `recommended`

## Details

A class with no state that's created at the call site, as in
`const Parser().parse(source)`, is a top-level function in disguise.
Callers depend on it directly, so it can't be mocked or replaced any more
than the function or static method it stands in for. Put the behavior where
its data lives:

- **On the type it works on**, as an instance member. Use an extension when
  you don't own the type.
- **In a dependency**, passed through a constructor, when callers need to
  swap it out in tests.

This rule reports a constructor called without arguments and followed by
`.` or `?.`, looking through parentheses:

- `const Foo().bar()` and `new Foo().bar()`, including named constructors
  such as `const Foo.named().bar()`.
- `Foo().bar()`, when `Foo` is written in UpperCamelCase like a type.
- Getters too, as in `const Foo().bar`.

These are allowed:

- Constructors with arguments, as in `File(path).readAsStringSync()`, since
  the instance carries that data.
- Cascades, as in `StringBuffer()..write(a)`, since their value is the
  instance itself.
- `Foo.named().bar()` without `const` or `new`. vaixell doesn't resolve
  types, so it can't tell a named constructor from a static method or a
  factory such as `DateTime.now()`.
- Instances kept in a variable or a field, as in `final parser = Parser();`.

**BAD:**

```dart
class RuleIds {
  const RuleIds();

  void check(List<Rule> rules) {}
}

class Loader {
  const Loader();

  void load(List<Rule> rules) => const RuleIds().check(rules);
}
```

**GOOD:**

```dart
class RuleSet {
  RuleSet(this.rules) {
    // Check the ids once, here.
  }

  final List<Rule> rules;
}

class Loader {
  const Loader({required this.parser});

  final Parser parser;

  Config load(String source) => parser.parse(source);
}
```

## Usage

```yaml
vaixell:
  rules:
    throwaway-instance: error # or off
```
