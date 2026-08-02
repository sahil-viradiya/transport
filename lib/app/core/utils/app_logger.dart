import 'package:flutter/foundation.dart';

/// Enterprise-grade structured logging utility.
/// Automatically silences verbose logs in release mode while preserving critical error telemetry.
class AppLogger {
  AppLogger._();

  /// Log debug message (ignored in release builds)
  static void d(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _log('DEBUG', message, error, stackTrace);
    }
  }

  /// Log info message (ignored in release builds)
  static void i(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _log('INFO', message, error, stackTrace);
    }
  }

  /// Log warning message
  static void w(String message, [Object? error, StackTrace? stackTrace]) {
    _log('WARN', message, error, stackTrace);
  }

  /// Log error message with optional exception and stack trace
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message, error, stackTrace);
  }

  static void _log(String level, String message, Object? error, StackTrace? stackTrace) {
    final timestamp = DateTime.now().toIso8601String();
    final logBuffer = StringBuffer('[$timestamp] [$level] $message');

    if (error != null) {
      logBuffer.write(' | Error: $error');
    }
    if (stackTrace != null) {
      logBuffer.write('\n$stackTrace');
    }

    debugPrint(logBuffer.toString());
  }
}
