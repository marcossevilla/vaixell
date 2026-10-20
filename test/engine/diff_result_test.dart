import 'package:test/test.dart';
import 'package:theseus_cli/theseus_cli.dart';

Violation _v(String id, {int line = 1}) => Violation(
  id: id,
  rule: 'r',
  severity: Severity.error,
  path: 'lib/a.dart',
  line: line,
  column: 1,
  message: 'm',
);

void main() {
  group(DiffResult, () {
    test('compares by id, ignoring locations', () {
      final diff = DiffResult.compare(
        base: ['removed-b', 'kept', 'removed-a', 'kept'],
        head: [_v('kept', line: 9), _v('added')],
      );
      expect(diff.added.map((v) => v.id), equals(['added']));
      expect(diff.fixed, equals(['removed-a', 'removed-b']));
    });

    test('is empty when nothing changed', () {
      final diff = DiffResult.compare(base: ['a'], head: [_v('a')]);
      expect(diff.added, isEmpty);
      expect(diff.fixed, isEmpty);
    });

    test('suppress drops added ids and keeps fixed ones', () {
      final diff = DiffResult(added: [_v('a'), _v('b')], fixed: const ['c']);
      final suppressed = diff.suppress({'a', 'c'});
      expect(suppressed.added.map((v) => v.id), equals(['b']));
      expect(suppressed.fixed, equals(['c']));
    });
  });
}
