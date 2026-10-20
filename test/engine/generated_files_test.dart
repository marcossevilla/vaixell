import 'package:test/test.dart';
import 'package:theseus_cli/src/engine/generated_files.dart';

void main() {
  group(GeneratedFiles, () {
    const generated = GeneratedFiles();

    for (final path in [
      'lib/a.g.dart',
      'lib/a.freezed.dart',
      'lib/router.gr.dart',
      'lib/assets.gen.dart',
      'lib/a.mocks.dart',
      'lib/api.pb.dart',
      'lib/api.pbenum.dart',
      'lib/api.pbgrpc.dart',
      'lib/api.pbjson.dart',
      'lib/api.pbserver.dart',
    ]) {
      test('matches $path', () => expect(generated.matches(path), isTrue));
    }

    for (final path in ['lib/a.dart', 'lib/g.dart', 'lib/config.dart']) {
      test('ignores $path', () => expect(generated.matches(path), isFalse));
    }
  });
}
