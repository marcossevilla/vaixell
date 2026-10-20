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
        base: [_v('kept'), _v('removed')],
        head: [_v('kept', line: 9), _v('added')],
      );
      expect(diff.added.map((v) => v.id), equals(['added']));
      expect(diff.fixed.map((v) => v.id), equals(['removed']));
    });

    test('is empty when nothing changed', () {
      final diff = DiffResult.compare(base: [_v('a')], head: [_v('a')]);
      expect(diff.added, isEmpty);
      expect(diff.fixed, isEmpty);
    });
  });
}
