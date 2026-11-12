# generated-json

Use json_serializable for `fromJson` and `toJson`.

**Default:** warning · **Preset:** `recommended`

## Details

Hand-written `fromJson` and `toJson` bodies repeat map access and casts for
every field, and they drift from the fields they parse. json_serializable
generates that code from the class itself. This rule reports:

- A `fromJson` constructor or `toJson` method in a class that isn't
  annotated with `@JsonSerializable`.
- A `fromJson` constructor or `toJson` method in an annotated class whose
  body does anything other than return the generated function. `fromJson`
  must return `_$<Class>FromJson(json, …)`, passing its first parameter, and
  `toJson` must return `_$<Class>ToJson(this, …)`. `<Class>` drops leading
  underscores, as json_serializable does, so `_User` uses `_$UserFromJson`.
  Both `=>` and `{ return …; }` bodies work, and the parameter can be
  null-checked, cast or parenthesized, as in
  `_$UserFromJson(json! as Map<String, dynamic>)`.
- A static `fromJson` method, since json_serializable expects a factory
  constructor. `static-method` reports it too. Make it a factory
  constructor rather than an instance method, which neither rule checks.
- A generative `fromJson` constructor, including a primary one such as
  `class const User.fromJson(...)`, since it can't return the generated
  function. Make it a factory constructor.
- The same members in an enum, whatever their body. Annotate the enum with
  `@JsonEnum()` and its values with `@JsonValue` instead.

`@JsonSerializable` and `@JsonSerializable()` both count, with or without an
import prefix such as `@js.JsonSerializable()`. Generic classes that use
`genericArgumentFactories` can pass the extra arguments and type arguments,
as in `_$PageFromJson<T>(json, fromJsonT)`. Fields that need custom parsing
should use a `JsonConverter` instead of a hand-written body.

Abstract and external members aren't reported, such as
`Map<String, dynamic> toJson();` in a base class. Neither are helpers that
convert another value rather than the type itself: instance `fromJson`
methods, and `toJson` methods whose first positional parameter is a value.
HydratedBloc's `fromJson(json)`/`toJson(state)` and a `JsonConverter`'s
`fromJson`/`toJson` are examples. Mixins, extensions and extension types
aren't checked, since they can't be annotated with `@JsonSerializable`.
Unlike `raw-json`, files under a `models` directory are checked too.

vaixell only parses files, so it doesn't check that json_serializable is a
dependency or that the `.g.dart` part exists. `build_runner` and the analyzer
already report those. For the same reason, some cases are reported or
skipped imperfectly:

- Only a literal `JsonSerializable` annotation counts. An alias such as
  `const jsonSerializable = JsonSerializable(...)` isn't recognized.
- A `toJson` parameter typed with a function typedef, such as
  `ToJsonT<T> toJsonT`, looks like a value, so the method isn't checked.
- Models written with freezed or dart_mappable are reported by design, since
  vaixell recommends a single serializer. Set `generated-json: off` in those
  repositories.
- A `fromJson` on a sealed or abstract class that dispatches on a type field
  is reported, though json_serializable can't generate it. Use a
  [baseline](../README.md#baselines) for those.

**BAD:**

```dart
class User {
  const User({required this.name});

  factory User.fromJson(Map<String, dynamic> json) =>
      User(name: json['name'] as String);

  final String name;

  Map<String, dynamic> toJson() => {'name': name};
}

enum Status {
  active,
  archived;

  factory Status.fromJson(String json) =>
      values.firstWhere((status) => status.name == json);

  String toJson() => name;
}
```

**GOOD:**

```dart
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  const User({required this.name, required this.status});

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  final String name;

  final Status status;

  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonEnum()
enum Status {
  @JsonValue('active')
  active,
  @JsonValue('archived')
  archived,
}
```

## Usage

```yaml
vaixell:
  rules:
    generated-json: error # default: warning; or off
```
