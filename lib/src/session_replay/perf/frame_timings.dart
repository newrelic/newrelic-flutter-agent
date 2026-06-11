class FrameTimingStats {
  final int iterations;
  final int nodeCount;
  final List<double> walkMs;
  final List<double> encodeMs;
  final List<double> jsonMs;

  const FrameTimingStats({
    required this.iterations,
    required this.nodeCount,
    required this.walkMs,
    required this.encodeMs,
    required this.jsonMs,
  });

  String report() {
    final wb = List<double>.of(walkMs)..sort();
    final eb = List<double>.of(encodeMs)..sort();
    final jb = List<double>.of(jsonMs)..sort();
    String row(String name, List<double> sorted) {
      final p50 = _pct(sorted, 50);
      final p95 = _pct(sorted, 95);
      final max = sorted.last;
      return '  $name p50=${p50.toStringAsFixed(2)}ms '
          'p95=${p95.toStringAsFixed(2)}ms '
          'max=${max.toStringAsFixed(2)}ms';
    }

    return '[SessionReplay] timings (n=$iterations, IR nodes=$nodeCount)\n'
        '${row("walk:  ", wb)}\n'
        '${row("encode:", eb)}\n'
        '${row("json:  ", jb)}';
  }

  static double _pct(List<double> sorted, int p) {
    if (sorted.isEmpty) return 0;
    final idx = ((p / 100.0) * (sorted.length - 1)).round();
    return sorted[idx];
  }
}
