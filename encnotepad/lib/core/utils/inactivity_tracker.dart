import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class InactivityTracker {
  Duration timeout;
  final VoidCallback onTimeout;
  Timer? _timer;

  InactivityTracker({
    Duration? timeout,
    required this.onTimeout,
  }) : timeout = timeout ?? const Duration(seconds: AppConstants.defaultAutoLockTimeoutSeconds);

  void start() {
    reset();
  }

  void reset() {
    _timer?.cancel();
    _timer = Timer(timeout, onTimeout);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void updateTimeout(Duration newTimeout) {
    timeout = newTimeout;
    reset();
  }
}
