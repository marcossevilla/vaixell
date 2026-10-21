import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';
import 'package:vaixell/src/command_runner.dart';
import 'package:vaixell/src/version.dart';

class _MockLogger extends Mock implements Logger;

class _MockProgress extends Mock implements Progress;

class _MockPubUpdater extends Mock implements PubUpdater;

const latestVersion = '0.0.0';

final updatePrompt =
    // We need to ignore this lint in order to match the exact message format.
    // ignore: leading_newlines_in_multiline_strings
    '''${lightYellow.wrap('Update available!')} ${lightCyan.wrap(packageVersion)} \u2192 ${lightCyan.wrap(latestVersion)}
Run ${lightCyan.wrap('vaixell update')} to update''';

void main() {
  group('VaixellCommandRunner', () {
    late PubUpdater pubUpdater;
    late Logger logger;
    late VaixellCommandRunner commandRunner;

    setUp(() {
      pubUpdater = _MockPubUpdater();

      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => packageVersion);

      logger = _MockLogger();

      commandRunner = VaixellCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
        interactive: true,
      );
    });

    test('shows update message when newer version exists', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => latestVersion);

      final result = await commandRunner.run(['--version']);
      expect(result, equals(ExitCode.success.code));
      verify(() => logger.info(updatePrompt)).called(1);
    });

    test('shows error message when failed to check for updates', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenThrow(Exception('Failed to check for updates'));

      await commandRunner.run(['--version']);
      verify(() => logger.err('Failed to check for updates.')).called(1);
    });

    test('Does not show update message when the shell calls the '
        'completion command', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => latestVersion);

      final result = await commandRunner.run(['completion']);
      expect(result, equals(ExitCode.success.code));
      verifyNever(() => logger.info(updatePrompt));
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

      final progress = _MockProgress();
      final progressLogs = <String>[];
      when(() => progress.complete(any())).thenAnswer((answer) {
        final message = answer.positionalArguments.elementAt(0) as String?;
        if (message != null) progressLogs.add(message);
      });
      when(() => logger.progress(any())).thenReturn(progress);

      final result = await commandRunner.run(['update']);
      expect(result, equals(ExitCode.success.code));
      verifyNever(() => logger.info(updatePrompt));
    });

    test('does not show update message for machine-readable '
        'check output', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => latestVersion);

      await commandRunner.run(['check', '--format=json']);
      verifyNever(() => pubUpdater.getLatestVersion(any()));
      verifyNever(() => logger.info(updatePrompt));
    });

    test('does not auto-install completion files for machine-readable '
        'check output', () async {
      await commandRunner.run(['check', '--format=json']);
      expect(commandRunner.enableAutoInstall, isFalse);
    });

    test('auto-installs completion files for a text check', () async {
      await commandRunner.run(['check']);
      expect(commandRunner.enableAutoInstall, isTrue);
    });

    group('when not interactive', () {
      setUp(() {
        commandRunner = VaixellCommandRunner(
          logger: logger,
          pubUpdater: pubUpdater,
          interactive: false,
        );
      });

      test('does not check for updates', () async {
        await commandRunner.run(['check']);
        verifyNever(() => pubUpdater.getLatestVersion(any()));
      });

      test('does not auto-install completion files', () async {
        await commandRunner.run(['check']);
        expect(commandRunner.enableAutoInstall, isFalse);
      });
    });

    test('shows update message after a text check', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => latestVersion);

      await commandRunner.run(['check']);
      verify(() => logger.info(updatePrompt)).called(1);
    });

    test(
      'can be instantiated without an explicit analytics/logger instance',
      () {
        final commandRunner = VaixellCommandRunner();
        expect(commandRunner, isNotNull);
        expect(commandRunner, isA<CompletionCommandRunner<int>>());
      },
    );

    test('handles FormatException', () async {
      const exception = FormatException('oops!');
      var isFirstInvocation = true;
      when(() => logger.info(any())).thenAnswer((_) {
        if (isFirstInvocation) {
          isFirstInvocation = false;
          throw exception;
        }
      });
      final result = await commandRunner.run(['--version']);
      expect(result, equals(ExitCode.usage.code));
      verify(() => logger.err(exception.message)).called(1);
      verify(() => logger.info(commandRunner.usage)).called(1);
    });

    test('handles UsageException', () async {
      final exception = UsageException('oops!', 'exception usage');
      var isFirstInvocation = true;
      when(() => logger.info(any())).thenAnswer((_) {
        if (isFirstInvocation) {
          isFirstInvocation = false;
          throw exception;
        }
      });
      final result = await commandRunner.run(['--version']);
      expect(result, equals(ExitCode.usage.code));
      verify(() => logger.err(exception.message)).called(1);
      verify(() => logger.info('exception usage')).called(1);
    });

    group('--version', () {
      test('outputs current version', () async {
        final result = await commandRunner.run(['--version']);
        expect(result, equals(ExitCode.success.code));
        verify(() => logger.info(packageVersion)).called(1);
      });
    });

    group('--verbose', () {
      test('enables verbose logging', () async {
        final result = await commandRunner.run(['--verbose']);
        expect(result, equals(ExitCode.success.code));

        verify(() => logger.detail('Argument information:')).called(1);
        verify(() => logger.detail('  Top level options:')).called(1);
        verify(() => logger.detail('  - verbose: true')).called(1);
        verifyNever(() => logger.detail('    Command options:'));
      });

      test('enables verbose logging for sub commands', () async {
        final result = await commandRunner.run([
          '--verbose',
          'check',
          '--format=text',
        ]);
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
        final result = await commandRunner.run([
          '--verbose',
          'check',
          '--format=json',
        ]);
        expect(result, equals(ExitCode.success.code));

        verifyNever(() => logger.detail(any()));
      });
    });
  });
}
