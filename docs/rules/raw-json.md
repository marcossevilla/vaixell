# raw-json

Keep raw JSON handling inside model classes.

**Default:** error · **Preset:** `recommended`

## Details

Passing raw JSON around spreads untyped data and parsing logic through a
codebase. This rule reports:

- `jsonDecode` and `json.decode` calls.
- `jsonEncode` and `json.encode` calls.
- `Map<String, dynamic>` types.

They are allowed:

- Inside `fromJson` constructors and methods, and inside `toJson` methods.
- In files under a `models` directory.
- At an I/O boundary that hands JSON straight to a model:
  - A decode call or `Map<String, dynamic>` cast passed directly to a
    `fromJson` call, as in
    `User.fromJson(jsonDecode(body) as Map<String, dynamic>)`.
  - An encode call whose argument isn't a collection literal, as in
    `jsonEncode(user)`, which calls `User.toJson`.

**BAD:**

```dart
class ApiClient {
  Future<String> getUserName() async {
    final body = await _get('/user');
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['name'] as String;
  }

  Future<void> createUser(String name) =>
      _post('/users', jsonEncode({'name': name}));
}
```

**GOOD:**

```dart
class ApiClient {
  Future<User> getUser() async {
    final body = await _get('/user');
    return User.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  Future<void> createUser(User user) => _post('/users', jsonEncode(user));
}

class User {
  const User({required this.name});

  factory User.fromJson(Map<String, dynamic> json) =>
      User(name: json['name'] as String);

  final String name;

  Map<String, dynamic> toJson() => {'name': name};
}
```

## Usage

```yaml
vaixell:
  rules:
    raw-json: warning # or off
```
