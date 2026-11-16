import 'package:test/test.dart';
import 'package:vaixell/src/rules/built_in_rule.dart';
import 'package:vaixell/src/rules/rule.dart';

final class const _BuiltIn() extends Rule with BuiltInRule {
  @override
  String get id => 'built-in';
}

void main() {
  group('RuleDocs', () {
    test('links to the rule page on main', () {
      expect(
        const RuleDocs('some-rule').url,
        Uri.parse(
          'https://github.com/marcossevilla/vaixell/blob/main/docs/rules/'
          'some-rule.md',
        ),
      );
    });
  });

  group('BuiltInRule', () {
    test('links to the docs of its id', () {
      expect(const _BuiltIn().docs, const RuleDocs('built-in').url);
    });
  });
}
