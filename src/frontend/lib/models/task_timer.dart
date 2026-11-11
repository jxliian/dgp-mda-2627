import 'dart:async';
import 'package:flutter/foundation.dart';

/// Uses elapsed wall time so delayed frames do not slow the countdown.
class TaskTimer extends ChangeNotifier {
  TaskTimer(this.totalSeconds, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final int totalSeconds;
  final DateTime Function() _now;
  int _elapsedMilliseconds = 0;
  DateTime? _startedAt;
  Timer? _ticker;
  bool get running => _startedAt != null;
  int get remainingSeconds {
    final elapsed =
        _elapsedMilliseconds +
        (_startedAt == null
            ? 0
            : _now().difference(_startedAt!).inMilliseconds);
    return ((totalSeconds * 1000 - elapsed) / 1000).ceil().clamp(
      0,
      totalSeconds,
    );
  }

  double get fraction =>
      totalSeconds == 0 ? 0 : remainingSeconds / totalSeconds;
  String get label =>
      '${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(remainingSeconds % 60).toString().padLeft(2, '0')}';
  void start() {
    if (running || remainingSeconds == 0) return;
    _startedAt = _now();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (remainingSeconds == 0) {
        pause();
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void pause() {
    if (_startedAt != null) {
      _elapsedMilliseconds += _now().difference(_startedAt!).inMilliseconds;
    }
    _startedAt = null;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void reset() {
    pause();
    _elapsedMilliseconds = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
