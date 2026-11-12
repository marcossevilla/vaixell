import 'package:test/test.dart';
import 'package:vaixell/src/options/config_exception.dart';
import 'package:yaml/yaml.dart';

void main() {
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

  group('YamlNodeConfigErrors', () {
    test('points at the node, 1-based', () {
      final map = loadYamlNode('a:\n  b: 1\n') as YamlMap;
      final node = (map.nodes['a']! as YamlMap).nodes['b']!;
      expect(
        node.configError('Bad.', path: 'o.yaml').toString(),
        equals('o.yaml:2:6: Bad.'),
      );
    });
  });

  group('YamlExceptionConfigErrors', () {
    test('points at the error, 1-based', () {
      late YamlException error;
      try {
        loadYaml('a: [');
      } on YamlException catch (e) {
        error = e;
      }
      final exception = error.toConfigException(path: 'o.yaml');
      expect(exception.path, equals('o.yaml'));
      expect(exception.message, equals(error.message));
      expect(exception.line, equals(error.span!.start.line + 1));
      expect(exception.column, equals(error.span!.start.column + 1));
    });
  });
}
