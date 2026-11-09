import 'package:test/test.dart';
import 'package:vaixell/testing.dart';
import 'package:vaixell/vaixell.dart';

/// Reports every class, and every import with its resolved path.
final class const _Rule()
    extends Rule
    with ChecksDeclarations, ChecksImports, SkipsDirectories {
  @override
  String get id => 'test';

  @override
  Set<String> get skippedDirectories => const {'models'};

  @override
  Finding? checkDeclaration(Declaration declaration) => switch (declaration) {
    ClassDeclaration(:final name) => Finding.at(declaration, message: name),
    _ => null,
  };

  @override
  Finding? checkImport(DartFile file, Import import) =>
      Finding.at(import, message: '${file.packagePath} ${import.path}');
}

/// Reports two findings at the same offset, in reverse source order.
final class const _UnorderedRule() extends Rule {
  @override
  String get id => 'unordered';

  @override
  List<Finding> check(DartFile file) => const [
    Finding(offset: 9, message: 'b'),
    Finding(offset: 0, message: 'a'),
    Finding(offset: 9, message: 'c'),
  ];
}

/// Reports the classes named one of [names].
final class const _NamedRule(final List<String> names)
    extends Rule
    with ChecksDeclarations {
  @override
  String get id => 'named';

  @override
  Finding? checkDeclaration(Declaration declaration) => switch (declaration) {
    ClassDeclaration(:final name) when names.contains(name) => Finding.at(
      declaration,
      message: '`$name` is not allowed.',
    ),
    _ => null,
  };
}

final _factory = RuleFactory('named', (options) {
  options.allowOnly({'names'});
  return _NamedRule([
    for (final name in options['names'].asList()) name.asString(),
  ]);
});

void main() {
  const tester = RuleTester();

  group(RuleTester, () {
    group('checkSource', () {
      test('returns the findings', () {
        final findings = tester.checkSource(const _Rule(), 'class A {}\n');
        expect(findings.map((f) => f.symbol), ['A']);
      });

      test('sorts the findings by offset, keeping ties in order', () {
        final findings = tester.checkSource(const _UnorderedRule(), '');
        expect(findings.map((f) => f.message), ['a', 'b', 'c']);
      });

      test('places the file in the package', () {
        final findings = tester.checkSource(
          const _Rule(),
          "import 'package:app/b.dart';\n",
          path: 'packages/app/lib/src/a.dart',
          package: const TestPackage(path: 'packages/app', name: 'app'),
        );
        expect(
          findings.single.message,
          'lib/src/a.dart packages/app/lib/b.dart',
        );
      });

      test('respects shouldCheck', () {
        final findings = tester.checkSource(
          const _Rule(),
          'class A {}\n',
          path: 'lib/models/a.dart',
        );
        expect(findings, isEmpty);
      });

      test('throws for a path outside the package lib/', () {
        for (final (path, package) in [
          ('test/a.dart', const TestPackage(path: '')),
          ('lib/a.dart', const TestPackage(path: 'packages/app')),
          ('packages/app/a.dart', const TestPackage(path: 'packages/app')),
        ]) {
          expect(
            () => tester.checkSource(
              const _Rule(),
              '',
              path: path,
              package: package,
            ),
            throwsArgumentError,
            reason: path,
          );
        }
      });

      test('throws naming each syntax error with its line and column', () {
        expect(
          () => tester.checkSource(const _Rule(), 'class A {}\nclass {\n'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(
                startsWith('`lib/a.dart` has syntax errors:\n  2:7: '),
                contains('\n  3:1: '),
              ),
            ),
          ),
        );
      });
    });

    group('createRule', () {
      test('builds the rule from the fixture', () {
        final rule = tester.createRule(
          _factory,
          fixture: 'test/fixtures/testing/names.yaml',
        );
        expect((rule as _NamedRule).names, ['A', 'B']);
      });

      test('round-trips with checkSource', () {
        final rule = tester.createRule(
          _factory,
          fixture: 'test/fixtures/testing/names.yaml',
        );
        final findings = tester.checkSource(
          rule,
          'class A {}\nclass B {}\nclass C {}\n',
        );
        expect(findings.map((f) => f.symbol), ['A', 'B']);
      });

      test('passes no options for an empty fixture', () {
        expect(
          () => tester.createRule(
            _factory,
            fixture: 'test/fixtures/testing/empty.yaml',
          ),
          throwsA(
            isA<ConfigException>().having(
              (e) => '$e',
              'toString()',
              'test/fixtures/testing/empty.yaml:1:1: `named` needs `names`.',
            ),
          ),
        );
      });

      test('reports option errors in the fixture', () {
        expect(
          () => tester.createRule(
            _factory,
            fixture: 'test/fixtures/testing/unknown_key.yaml',
          ),
          throwsA(
            isA<ConfigException>().having(
              (e) => '$e',
              'toString()',
              startsWith(
                'test/fixtures/testing/unknown_key.yaml:2:1: Unknown key `nmes`',
              ),
            ),
          ),
        );
      });

      test('reports invalid YAML in the fixture', () {
        expect(
          () => tester.createRule(
            _factory,
            fixture: 'test/fixtures/testing/invalid.yaml',
          ),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.path,
              'path',
              'test/fixtures/testing/invalid.yaml',
            ),
          ),
        );
      });
    });
  });
}
