import 'dart:developer';

import 'package:logging/logging.dart';

final logger = _getLogger('ENGINE');

bool _loggerListened = false;
Logger _getLogger(String name) {
  final logger = Logger('CCHESS');
  if (!_loggerListened && hierarchicalLoggingEnabled) {
    _loggerListened = true;
    logger.onRecord.listen((record) {
      log(
        record.message,
        time: record.time,
        level: record.level.value,
        error: record.error,
        stackTrace: record.stackTrace,
        sequenceNumber: record.sequenceNumber,
      );
    });
  }
  return logger;
}
