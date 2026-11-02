import 'package:test/test.dart';
import 'package:vaixell/src/config/presets.dart';
import 'package:vaixell/vaixell.dart';

void main() {
  group(Config, () {
    test('recommended uses the recommended preset', () {
      final config = Config.recommended();
      expect(config.severities, equals(const Presets().all['recommended']));
      expect(config.exclude, isEmpty);
      expect(config.excludes('lib/a.dart'), isFalse);
    });
  });

  group(ConfigException, () {
    test('prints file:line:col and the message', () {
      const error = ConfigException(
        'Bad.',
        path: 'analysis_options.yaml',
        line: 3,
        column: 5,
      );
      expect(error.toString(), equals('analysis_options.yaml:3:5: Bad.'));
    });
  });
}
