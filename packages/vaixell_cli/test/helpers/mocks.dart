import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';

class MockLogger extends Mock implements Logger;

class MockProgress extends Mock implements Progress;

class MockPubUpdater extends Mock implements PubUpdater;

/// A version that's never the CLI's own, for "update available" cases.
const latestVersion = '0.0.0';
