import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';
import 'package:vaixell_cli/vaixell_cli.dart';

import '../../helpers/mocks.dart';

void main() {
  group(UpdateCommand, () {
    late PubUpdater pubUpdater;
    late Logger logger;
    late Progress checkProgress;
    late Progress updateProgress;

    Future<int?> run() =>
        (CommandRunner<int>('vaixell', '')..addCommand(
              UpdateCommand(logger: logger, pubUpdater: pubUpdater),
            ))
            .run(['update']);

    void stubUpdate(Future<ProcessResult> Function() result) => when(
      () => pubUpdater.update(
        packageName: any(named: 'packageName'),
        versionConstraint: any(named: 'versionConstraint'),
      ),
    ).thenAnswer((_) => result());

    setUp(() {
      pubUpdater = MockPubUpdater();
      logger = MockLogger();
      checkProgress = MockProgress();
      updateProgress = MockProgress();
      when(() => logger.progress('Checking for updates'))
          .thenReturn(checkProgress);
      when(() => logger.progress('Updating to $latestVersion'))
          .thenReturn(updateProgress);
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => latestVersion);
    });

    test('handles pub latest version query errors', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenThrow(Exception('oops'));
      expect(await run(), equals(ExitCode.software.code));
      verify(checkProgress.fail).called(1);
      verify(() => logger.err('Exception: oops')).called(1);
      verifyNever(
        () => pubUpdater.update(
          packageName: any(named: 'packageName'),
          versionConstraint: any(named: 'versionConstraint'),
        ),
      );
    });

    test('handles pub update errors', () async {
      stubUpdate(() => throw Exception('oops'));
      expect(await run(), equals(ExitCode.software.code));
      verify(updateProgress.fail).called(1);
      verify(() => logger.err('Exception: oops')).called(1);
    });

    test('handles pub update process errors', () async {
      const error = 'Oh no! Installing this is not possible right now!';
      stubUpdate(() async => ProcessResult(0, 1, null, error));
      expect(await run(), equals(ExitCode.software.code));
      verify(updateProgress.fail).called(1);
      verify(() => logger.err('Error updating CLI: $error')).called(1);
    });

    test('updates when newer version exists', () async {
      stubUpdate(
        () async => ProcessResult(0, ExitCode.success.code, null, null),
      );
      expect(await run(), equals(ExitCode.success.code));
      verify(() => checkProgress.complete('Checked for updates')).called(1);
      verify(() => updateProgress.complete('Updated to $latestVersion'))
          .called(1);
      verify(
        () => pubUpdater.update(
          packageName: VaixellCommandRunner.packageName,
          versionConstraint: latestVersion,
        ),
      ).called(1);
    });

    test('does not update when already on latest version', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => VaixellCommandRunner.packageVersion);
      expect(await run(), equals(ExitCode.success.code));
      verify(() => logger.info('CLI is already at the latest version.'))
          .called(1);
      verifyNever(() => logger.progress('Updating to $latestVersion'));
      verifyNever(
        () => pubUpdater.update(
          packageName: any(named: 'packageName'),
          versionConstraint: any(named: 'versionConstraint'),
        ),
      );
    });

    test('creates its own pub updater by default', () {
      expect(UpdateCommand(logger: logger).name, equals('update'));
    });
  });
}
