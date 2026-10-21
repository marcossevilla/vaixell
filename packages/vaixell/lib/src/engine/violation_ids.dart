/// Builds stable violation ids.
///
/// Ids don't include line numbers, so moving code around doesn't change
/// them. When the same id appears more than once in a file, the second
/// occurrence gets `#2`, the third `#3`, and so on, in source order.
class ViolationIds {
  final Map<String, int> _counts = {};

  /// Returns the id for the next occurrence of [symbol] from [rule] in
  /// [path].
  ///
  /// Call this in source order for each file.
  String next({required String rule, required String path, String? symbol}) {
    final base = symbol == null ? '$rule:$path' : '$rule:$path:$symbol';
    final count = _counts.update(base, (n) => n + 1, ifAbsent: () => 1);
    return count == 1 ? base : '$base#$count';
  }
}
