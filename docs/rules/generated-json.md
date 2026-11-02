# generated-json

Use json_serializable for `fromJson` and `toJson`.

**Default:** warning · **Preset:** `recommended`

## Details

Hand-written `fromJson` and `toJson` bodies repeat map access and casts for
every field, and they drift from the fields they parse. json_serializable
generates that code from the class itself. This rule reports:

- A `fromJson` factory constructor or `toJson` method in a class that isn't
  annotated with `@JsonSerializable`.
- A `fromJson` factory constructor or `toJson` method in an annotated class
  whose body does anything other than return the generated function.
  `fromJson` must return `_$<Class>FromJson(json, …)`, passing its first
  parameter, and `toJson` must return `_$<Class>ToJson(this, …)`. Both
  `=>` and `{ return …; }` bodies work.
- A `fromJson` method, static or not, since json_serializable expects a
  factory constructor.
- Any `fromJson` or `toJson` in an enum, whatever its body. Annotate the enum
  with `@JsonEnum()` and its values with `@JsonValue` instead.

`@JsonSerializable` and `@JsonSerializable()` both count, with or without an
import prefix such as `@js.JsonSerializable()`. Generic classes that use
`genericArgumentFactories` can pass the extra arguments and type arguments,
as in `_$PageFromJson<T>(json, fromJsonT)`. Fields that need custom parsing
should use a `JsonConverter` instead of a hand-written body.

Mixins, extensions and extension types aren't checked, since they can't be
annotated with `@JsonSerializable`. Unlike `raw-json`, files under a `models`
directory are checked too. Generated files are never checked.

vaixell only parses files, so it doesn't check that json_serializable is a
dependency or that the `.g.dart` part exists. `build_runner` and the analyzer
already report those.

### freezed and dart_mappable

vaixell recommends a single serializer, json_serializable. Models written
with `@freezed` or `@MappableClass` are reported by design, even though their
`fromJson` is generated. If your repository uses freezed or dart_mappable,
turn the rule off:

```yaml
vaixell:
  rules:
    generated-json: off
```

### Existing repositories

The rule is a warning, so it doesn't fail the run. To hide the existing
findings and only see new ones, write a baseline and check against it:

```sh
vaixell check --write-baseline=vaixell_baseline.json
vaixell check --baseline=vaixell_baseline.json
```

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
    generated-json: error # or off
```
