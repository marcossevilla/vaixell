// PROTOTYPE: runs today's rules and the model-based ones on edge cases that
// today's tests don't pin down, and checks they report the same findings.

import 'package:test/test.dart';
import 'package:vaixell/src/rules/await_receiver.dart' as today;
import 'package:vaixell/src/rules/generated_json.dart' as today;
import 'package:vaixell/src/rules/raw_json.dart' as today;
import 'package:vaixell/src/rules/rule.dart';

import '../../test/helpers/parse.dart';
import 'shim.dart' as model;

const _sources = [
  // Member access shapes around json/jsonDecode.
  'f() { a?.json.decode(s); x..json.decode(s); x..jsonDecode(s); }',
  'f() { (a).json.decode(s); this.json.decode(s); a.b.json.decode(s); }',
  'f() { a?.jsonDecode(s); x..a.jsonDecode(s); x?..jsonEncode(s); }',
  // Calls that only look like fromJson calls.
  'void f() { (User.fromJson)(jsonDecode(s)); new jsonDecode(s); }',
  'void f() { User.fromJson(x: jsonDecode(s)); f()(jsonDecode(s)); }',
  'User f() => .fromJson(jsonDecode(s) as Map<String, dynamic>);',
  'f() { x..fromJson(jsonDecode(s)); const User.fromJson(jsonDecode(s)); }',
  'class A { A() : this.fromJson(jsonDecode(s)); }',
  'class A { A() : super(jsonDecode(s)); }',
  // Types in odd places.
  'typedef J = Map<String, dynamic>;',
  'void Function(Map<String, dynamic>) f = (Map<String, dynamic> m) {};',
  '(Map<String, dynamic>, {core.Map<core.String, dynamic>? b}) r = x;',
  'Map<String?, dynamic> a; Map<dynamic, String> c;',
  'Map<String, Map<String, dynamic>> b;',
  'class A<T extends Map<String, dynamic>> extends B<Map<String, dynamic>> {}',
  'f() { x is Map<String, dynamic>; <Map<String, dynamic>>[]; }',
  'f() { g<Map<String, dynamic>>(); }',
  // Annotations.
  "@Foo(jsonDecode('')) final a = 1, b = 2;",
  'class C { @Foo(<Map<String, dynamic>>[]) final a = 1, b = 2; }',
  "@Foo(jsonDecode('')) class C { @Bar(jsonEncode([])) void m() {} }",
  "class C { @Foo(jsonDecode('')) C.fromJson(); }",
  "enum E { a(jsonDecode('')); const E(this.x); final x; }",
  // Awaits.
  'f() async { (await a)?..b(); (await a)?[0]; await a()(); await (a)(); }',
  'f() async { await new A().x; (await new A()).x; }',
  'f() async { await super.x; (await this.a).b; }',
  'f() async { (await a)++; -(await a); (await a) as T..b(); [(await a)!]; }',
  'f() async { (await a) ?? b; x = [for (final y in await a) y]; }',
  // generated-json bodies.
  r'''
@JsonSerializable()
class A {
  factory A.fromJson(Map<String, dynamic> json) => _$AFromJson((json));
  Map<String, dynamic> toJson() { return _$AToJson(this,); }
}
@JsonSerializable()
class B {
  factory B.fromJson(Map<String, dynamic> json) => _$BFromJson(json: json);
  Map<String, dynamic> toJson() async => _$BToJson(this);
}
@json.JsonSerializable(createFactory: false, createToJson: false)
class C {
  C.fromJson(Object? data) : x = 1 { return _$CFromJson(data!); }
  Map<String, dynamic> toJson() { final x = 1; return _$CToJson(this); }
  static C fromJson(Map<String, dynamic> json) => _$CFromJson(json);
}
@JsonSerializable.named()
class D { Map<String, dynamic> toJson() => this._$DToJson(this); }
@JsonSerializable(createToJson: 0)
class E {
  Map<String, dynamic> toJson() => _$EToJson(this as E);
  external factory E.fromJson(Map<String, dynamic> json);
}
''',
];

void main() {
  final pairs = <(Rule, Rule)>[
    (const today.AwaitReceiverRule(), const model.AwaitReceiverRule()),
    (const today.RawJsonRule(), const model.RawJsonRule()),
    (const today.GeneratedJsonRule(), const model.GeneratedJsonRule()),
  ];

  List<(int, String?, String)> findings(Rule rule, ParsedFile file) =>
      [for (final f in rule.check(file)) (f.offset, f.symbol, f.message)]
        ..sort((a, b) => a.$1.compareTo(b.$1));

  for (final (old, model) in pairs) {
    group(old.id, () {
      for (final source in _sources) {
        test(source.split('\n').first, () {
          final file = parse(source);
          expect(findings(model, file), equals(findings(old, file)));
        });
      }
    });
  }
}
