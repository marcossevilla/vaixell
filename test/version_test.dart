import 'dart:io';

import 'package:test/test.dart';
import 'package:theseus_cli/theseus_cli.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('TheseusVersion.current matches pubspec.yaml', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
    expect(TheseusVersion.current, equals(pubspec['version']));
  });
}
