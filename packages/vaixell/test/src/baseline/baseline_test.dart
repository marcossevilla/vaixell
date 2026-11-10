import 'package:test/test.dart';
import 'package:vaixell/vaixell.dart';

void main() {
  group(Baseline, () {
    group('toJson', () {
      test('sorts and dedupes the ids', () {
        expect(
          Baseline(['b', 'a', 'b']).toJson(),
          equals({
            'schemaVersion': 1,
            'violations': ['a', 'b'],
          }),
        );
      });
    });

    group('fromJson', () {
      test('reads the ids', () {
        final baseline = Baseline.fromJson({
          'schemaVersion': 1,
          'violations': ['a', 'b'],
        });
        expect(baseline.ids, equals({'a', 'b'}));
      });

      for (final (name, json, message) in [
        (
          'a missing version',
          <String, Object?>{'violations': <Object?>[]},
          'Expected `schemaVersion` 1, found null.',
        ),
        (
          'another version',
          {'schemaVersion': 2, 'violations': <Object?>[]},
          'Expected `schemaVersion` 1, found 2.',
        ),
        (
          'missing violations',
          {'schemaVersion': 1},
          '`violations` must be a list of violation ids.',
        ),
        (
          'non-string ids',
          {
            'schemaVersion': 1,
            'violations': [1],
          },
          '`violations` must be a list of violation ids.',
        ),
      ]) {
        test('rejects $name', () {
          expect(
            () => Baseline.fromJson(json),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'message',
                message,
              ),
            ),
          );
        });
      }
    });
  });
}
