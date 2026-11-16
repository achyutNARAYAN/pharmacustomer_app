import 'package:flutter/foundation.dart';

/// Lightweight application logger wrapping debugPrint.
class AppLogger {
  const AppLogger();

  void debug(String message) {
    if (!kReleaseMode) debugPrint('[DEBUG] $message');
  }

  void info(String message) {
    if (!kReleaseMode) debugPrint('[INFO] $message');
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[WARN] $message${error != null ? ' - Error: $error' : ''}');
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] $message${error != null ? ' - Error: $error' : ''}');
  }
}

/// Backward compatibility alias.
typedef ConsoleLogger = AppLogger;
