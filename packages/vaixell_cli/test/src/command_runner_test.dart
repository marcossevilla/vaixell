import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';
import 'package:vaixell_cli/vaixell_cli.dart';

import '../helpers/buffered_logger.dart';
import '../helpers/mocks.dart';

final _updatePrompt =
    // We need to ignore this lint in order to match the exact message format.
    // ignore: leading_newlines_in_multiline_strings
    '''${lightYellow.wrap('Update available!')} ${lightCyan.wrap(VaixellCommandRunner.packageVersion)} \u2192 ${lightCyan.wrap(latestVersion)}
Run ${lightCyan.wrap('vaixell update')} to update''';

/// Reports every class.
final class const _ClassRule() extends Rule with ChecksDeclarations {
  @override
  String get id => 'no-class';

  @override
  Finding? checkDeclaration(Declaration declaration) => switch (declaration) {
    ClassDeclaration() => Finding.at(declaration, message: 'A class.'),
    _ => null,
  };
}

/// Throws a [FormatException] for every declaration.
final class const _ThrowingRule() extends Rule with ChecksDeclarations {
  @override
  String get id => 'throwing';

  @override
  Finding? checkDeclaration(Declaration declaration) =>
      throw const FormatException('rule bug');
}

void main() {
  group(VaixellCommandRunner, () {
    late PubUpdater pubUpdater;
    late Logger logger;
    late VaixellCommandRunner commandRunner;
    late bool interactive;

    /// Runs [args] on a new runner in the sandbox, where completion files
    /// would go to a sandbox home, so no test touches the real shell config.
    Future<int> run(List<String> args) => IOOverrides.runZoned(
      () =>
          (commandRunner = VaixellCommandRunner(
                logger: logger,
                pubUpdater: pubUpdater,
                interactive: interactive,
              )..environmentOverride = {'SHELL': '/bin/zsh', 'HOME': d.sandbox})
              .run(args),
      getCurrentDirectory: () => Directory(d.sandbox),
    );

    setUp(() {
      pubUpdater = MockPubUpdater();
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => VaixellCommandRunner.packageVersion);
      logger = MockLogger();
      interactive = true;
    });

    test('shows update message when newer version exists', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => latestVersion);

      final result = await run(['--version']);
      expect(result, equals(ExitCode.success.code));
      verify(() => logger.info(_updatePrompt)).called(1);
    });

    test('shows error message when failed to check for updates', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenThrow(Exception('Failed to check for updates'));

      await run(['--version']);
      verify(() => logger.err('Failed to check for updates.')).called(1);
    });

    test('does not show update message when the shell calls the '
        'completion command', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => latestVersion);

      final result = await run(['completion']);
      expect(result, equals(ExitCode.success.code));
      verifyNever(() => logger.info(_updatePrompt));
    });

    test('does not show update message when using update command', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => latestVersion);
      when(
        () => pubUpdater.update(
          packageName: VaixellCommandRunner.packageName,
          versionConstraint: any(named: 'versionConstraint'),
        ),
      ).thenAnswer(
        (_) async => ProcessResult(0, ExitCode.success.code, null, null),
      );
      when(
        () => pubUpdater.isUpToDate(
          packageName: any(named: 'packageName'),
          currentVersion: any(named: 'currentVersion'),
        ),
      ).thenAnswer((_) async => true);
      when(() => logger.progress(any())).thenReturn(MockProgress());

      final result = await run(['update']);
      expect(result, equals(ExitCode.success.code));
      verifyNever(() => logger.info(_updatePrompt));
    });

    test('does not show update message for machine-readable '
        'check output', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => latestVersion);

      await run(['check', '--format=json']);
      verifyNever(() => pubUpdater.getLatestVersion(any()));
      verifyNever(() => logger.info(_updatePrompt));
    });

    test('does not auto-install completion files for machine-readable '
        'check output', () async {
      await run(['check', '--format=json']);
      expect(commandRunner.enableAutoInstall, isFalse);
    });

    test('auto-installs completion files for a text check', () async {
      await run(['check']);
      expect(commandRunner.enableAutoInstall, isTrue);
    });

    group('when not interactive', () {
      setUp(() => interactive = false);

      test('does not check for updates', () async {
        await run(['check']);
        verifyNever(() => pubUpdater.getLatestVersion(any()));
      });

      test('does not auto-install completion files', () async {
        await run(['check']);
        expect(commandRunner.enableAutoInstall, isFalse);
      });
    });

    test('shows update message after a text check', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => latestVersion);

      await run(['check']);
      verify(() => logger.info(_updatePrompt)).called(1);
    });

    test('checks with the given rules', () async {
      await d.dir('lib', [d.file('a.dart', 'class A {}\n')]).create();
      final out = StringBuffer();
      final code = await IOOverrides.runZoned(
        () => VaixellCommandRunner(
          logger: bufferedLogger(out: out, err: StringBuffer()),
          interactive: false,
          rules: [...Recommended.rules, const _ClassRule()],
        ).run(['check']),
        getCurrentDirectory: () => Directory(d.sandbox),
      );
      expect(code, equals(CheckCommand.violationsExitCode));
      expect(
        out.toString(),
        startsWith('lib/a.dart:1:7: error: A class. [no-class:lib/a.dart:A]'),
      );
    });

    test('creates its own logger and pub updater by default', () {
      expect(VaixellCommandRunner().executableName, equals('vaixell'));
    });

    for (final (name, args) in [
      ('an unknown flag', ['--nope']),
      ('an unknown command', ['bogus']),
      ('an invalid option value', ['check', '--format=xml']),
    ]) {
      test('exits 64 with usage for $name', () async {
        expect(await run(args), equals(ExitCode.usage.code));
        verify(() => logger.err(any())).called(1);
        verify(() => logger.info(any(that: contains('Usage: vaixell'))))
            .called(1);
      });
    }

    test('prints usage without arguments', () async {
      expect(await run([]), equals(ExitCode.success.code));
      verify(() => logger.info(any(that: contains('Usage: vaixell'))))
          .called(1);
    });

    test('lets a $FormatException from a command surface', () async {
      await d.dir('lib', [d.file('a.dart', 'class A {}\n')]).create();
      interactive = false;
      await expectLater(
        IOOverrides.runZoned(
          () => VaixellCommandRunner(
            logger: bufferedLogger(out: StringBuffer(), err: StringBuffer()),
            interactive: false,
            rules: [const _ThrowingRule()],
          ).run(['check']),
          getCurrentDirectory: () => Directory(d.sandbox),
        ),
        throwsFormatException,
      );
    });

    group('--version', () {
      test('outputs current version', () async {
        final result = await run(['--version']);
        expect(result, equals(ExitCode.success.code));
        verify(() => logger.info(VaixellCommandRunner.packageVersion))
            .called(1);
      });

      test('matches the pubspec version', () {
        // Tests run from the package root, so read the pubspec directly
        // rather than resolving `package:` URIs, which `very_good test`
        // does not support.
        final pubspec = File('pubspec.yaml').readAsStringSync();
        final version = RegExp(
          r'^version: (\S+)$',
          multiLine: true,
        ).firstMatch(pubspec)!.group(1);
        expect(VaixellCommandRunner.packageVersion, equals(version));
      });
    });

    group('--verbose', () {
      test('enables verbose logging', () async {
        final result = await run(['--verbose']);
        expect(result, equals(ExitCode.success.code));

        verify(() => logger.detail('Argument information:')).called(1);
        verify(() => logger.detail('  Top level options:')).called(1);
        verify(() => logger.detail('  - verbose: true')).called(1);
        verifyNever(() => logger.detail('    Command options:'));
      });

      test('enables verbose logging for sub commands', () async {
        final result = await run(['--verbose', 'check', '--format=text']);
        expect(result, equals(ExitCode.success.code));

        verify(() => logger.detail('Argument information:')).called(1);
        verify(() => logger.detail('  Top level options:')).called(1);
        verify(() => logger.detail('  - verbose: true')).called(1);
        verify(() => logger.detail('  Command: check')).called(1);
        verify(() => logger.detail('    Command options:')).called(1);
        verify(() => logger.detail('    - format: text')).called(1);
      });

      test('does not log arguments for machine-readable check '
          'output', () async {
        final result = await run(['--verbose', 'check', '--format=json']);
        expect(result, equals(ExitCode.success.code));

        verifyNever(() => logger.detail(any()));
      });
    });
  });
}
