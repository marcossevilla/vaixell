import 'package:test/test.dart';
import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/options/option_value.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

DartFile _parse(String source, {String path = 'lib/a.dart'}) =>
    const DartFileParser().parse(path: path, content: source);

final class const _PlainRule() extends Rule {
  @override
  String get id => 'plain';
}

/// Reports every element it's asked about, and counts the hooks it runs.
base mixin _Reports on Rule {
  final List<String> hooks = [];

  Finding report(Reportable element, String hook) {
    hooks.add(hook);
    return Finding.at(element, message: hook);
  }
}

final class _EverythingRule extends Rule
    with
        _Reports,
        ChecksDeclarations,
        ChecksMembers,
        ChecksImports,
        ChecksExpressions,
        ChecksTypeAnnotations {
  @override
  String get id => 'everything';

  @override
  Finding? checkDeclaration(Declaration declaration) =>
      report(declaration, 'declaration');

  @override
  Finding? checkMember(TypeDeclaration type, Member member) =>
      report(member, 'member of ${type.name}');

  @override
  Finding? checkImport(DartFile file, Import import) =>
      report(import, 'import in ${file.path}');

  @override
  Finding? checkExpression(Expression expression) =>
      report(expression, 'expression');

  @override
  Finding? checkTypeAnnotation(TypeAnnotation type) => report(type, 'type');
}

/// The same hooks as [_EverythingRule], mixed in the other way around.
final class _ReversedRule extends Rule
    with
        _Reports,
        ChecksTypeAnnotations,
        ChecksExpressions,
        ChecksImports,
        ChecksMembers,
        ChecksDeclarations {
  @override
  String get id => 'reversed';

  @override
  Finding? checkDeclaration(Declaration declaration) =>
      report(declaration, 'declaration');

  @override
  Finding? checkMember(TypeDeclaration type, Member member) =>
      report(member, 'member of ${type.name}');

  @override
  Finding? checkImport(DartFile file, Import import) =>
      report(import, 'import in ${file.path}');

  @override
  Finding? checkExpression(Expression expression) =>
      report(expression, 'expression');

  @override
  Finding? checkTypeAnnotation(TypeAnnotation type) => report(type, 'type');
}

final class _ModelsRule extends Rule
    with _Reports, ChecksDeclarations, SkipsDirectories {
  @override
  String get id => 'models';

  @override
  Set<String> get skippedDirectories => const {'models'};

  @override
  Finding? checkDeclaration(Declaration declaration) =>
      report(declaration, 'declaration');
}

final class _NothingRule extends Rule with _Reports, ChecksDeclarations {
  @override
  String get id => 'nothing';

  @override
  bool shouldCheck(DartFile file) => false;

  @override
  Finding? checkDeclaration(Declaration declaration) =>
      report(declaration, 'declaration');
}

final class _SometimesRule extends Rule with ChecksDeclarations {
  @override
  String get id => 'sometimes';

  @override
  Finding? checkDeclaration(Declaration declaration) => switch (declaration) {
    TopLevelFunction() => Finding.at(declaration, message: 'f'),
    _ => null,
  };
}

/// Reports every class named one of [names].
final class const _NamedRule(
  final List<String> names, {
  @override final String id = 'named',
}) extends Rule with ChecksDeclarations {
  @override
  Finding? checkDeclaration(Declaration declaration) => switch (declaration) {
    ClassDeclaration(:final name) when names.contains(name) => Finding.at(
      declaration,
      message: name,
    ),
    _ => null,
  };
}

void main() {
  group(Finding, () {
    group('at', () {
      const source = "import 'dart:async';\n";
      final import = const DartFileParser()
          .parse(path: 'lib/a.dart', content: source)
          .imports
          .single;
      final error = const DartFileParser()
          .parse(path: 'lib/a.dart', content: 'class A {\n')
          .errors
          .first;

      test("takes the element's offset and symbol", () {
        final finding = Finding.at(import, message: 'm');
        expect(finding.offset, import.offset);
        expect(finding.message, 'm');
        expect(finding.symbol, 'dart:async');
      });

      test('appends the qualifier to the symbol', () {
        final finding = Finding.at(import, message: 'm', qualifier: 'q');
        expect(finding.symbol, 'dart:async@q');
      });

      test('keeps a null symbol without a qualifier', () {
        expect(Finding.at(error, message: 'm').symbol, isNull);
      });

      test('uses only the qualifier when the element has no symbol', () {
        final finding = Finding.at(error, message: 'm', qualifier: 'q');
        expect(finding.offset, error.offset);
        expect(finding.symbol, '@q');
      });
    });
  });

  group(Rule, () {
    test('has defaults', () {
      const rule = _PlainRule();
      final file = _parse('void f() {}');
      expect(rule.defaultSeverity, Severity.error);
      expect(rule.recommended, isTrue);
      expect(rule.shouldCheck(file), isTrue);
      expect(rule.check(file), isEmpty);
    });
  });

  group('Checks mixins', () {
    const source = """
import 'b.dart';
class C { int m(String s) => s.length; }
void f() {}
""";

    test('visit every element and sort the findings by offset', () {
      final rule = _EverythingRule();
      final findings = rule.check(_parse(source));
      expect(findings.map((f) => f.message), [
        'import in lib/a.dart',
        'declaration',
        'type',
        'member of C',
        'type',
        'expression',
        'expression',
        'type',
        'declaration',
      ]);
      final offsets = findings.map((f) => f.offset).toList();
      expect(offsets, orderedEquals([...offsets]..sort()));
    });

    test('combine in any order', () {
      List<(int, String?, String)> findingsOf(Rule rule) => [
        for (final f in rule.check(_parse(source)))
          (f.offset, f.symbol, f.message),
      ];
      expect(findingsOf(_ReversedRule()), findingsOf(_EverythingRule()));
    });

    test('leave out elements without a finding', () {
      final findings = _SometimesRule().check(
        _parse('class C {}\nvoid f() {}'),
      );
      expect(findings.map((f) => f.symbol), ['f']);
    });

    test('run no hook when shouldCheck is false', () {
      final rule = _NothingRule();
      expect(rule.check(_parse('void f() {}')), isEmpty);
      expect(rule.hooks, isEmpty);
    });
  });

  group(SkipsDirectories, () {
    test('skips files under any of the directories', () {
      final rule = _ModelsRule();
      final skipped = _parse('class A {}', path: 'lib/src/models/a.dart');
      expect(rule.shouldCheck(skipped), isFalse);
      expect(rule.check(skipped), isEmpty);
      expect(rule.hooks, isEmpty);
    });

    test('checks other files', () {
      final rule = _ModelsRule();
      final file = _parse('class A {}', path: 'lib/src/model/a.dart');
      expect(rule.shouldCheck(file), isTrue);
      expect(rule.check(file).map((f) => f.symbol), ['A']);
    });
  });

  group(RuleFactory, () {
    Rule create(OptionValue options) => _NamedRule([
      for (final name in options['names'].asList()) name.asString(),
    ]);

    test('has defaults', () {
      final factory = RuleFactory('named', create);
      expect(factory.id, 'named');
      expect(factory.defaultSeverity, Severity.error);
      expect(factory.recommended, isTrue);
    });

    test('keeps the given severity and recommended', () {
      final factory = RuleFactory(
        'named',
        create,
        defaultSeverity: Severity.warning,
        recommended: false,
      );
      expect(factory.defaultSeverity, Severity.warning);
      expect(factory.recommended, isFalse);
    });
  });

  group(RuleBuilder, () {
    final options = const OptionValues().empty(name: 'named', path: 'a.yaml');

    test('builds a plain rule as itself', () {
      const rule = _PlainRule();
      expect(const RuleBuilder().build(rule, options), same(rule));
    });

    test("builds a factory's rule from the options", () {
      const rule = _NamedRule(['A']);
      final factory = RuleFactory('named', (given) {
        expect(given, same(options));
        return rule;
      });
      expect(const RuleBuilder().build(factory, options), same(rule));
    });

    test('throws when the built rule has another id', () {
      final factory = RuleFactory(
        'named',
        (_) => const _NamedRule([], id: 'x'),
      );
      expect(
        () => const RuleBuilder().build(factory, options),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'The factory for `named` built a rule with id `x`.',
          ),
        ),
      );
    });
  });
}
