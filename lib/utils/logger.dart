import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class Logger {
  static void log(LogLevel level, String message) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp][${level.name.toUpperCase()}] $message');
    }
  }

  static void debug(String message) => log(LogLevel.debug, message);
  static void info(String message) => log(LogLevel.info, message);
  static void warning(String message) => log(LogLevel.warning, message);
  static void error(String message) => log(LogLevel.error, message);
}