import 'dart:io';

import 'package:test/test.dart';
import 'package:vaixell/vaixell.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('VaixellVersion.current matches pubspec.yaml', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
    expect(VaixellVersion.current, equals(pubspec['version']));
  });
}
