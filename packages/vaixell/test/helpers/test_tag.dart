/// Tags for selecting or excluding groups of tests.
abstract class TestTag {
  /// Tests that compare output with a golden file, rewritten with
  /// `UPDATE_GOLDENS=1`.
  static const golden = 'golden';
}
