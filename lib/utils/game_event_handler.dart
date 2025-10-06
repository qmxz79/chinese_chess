import 'package:flutter/foundation.dart';

class GameEventHandler {
  static void handleError(String error, {StackTrace? stackTrace}) {
    if (kDebugMode) {
      print('Error: $error');
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
      }
    }
    
    // TODO: 添加错误上报逻辑
  }
  
  static void handleInvalidMove(String move, String reason) {
    handleError('Invalid move: $move, Reason: $reason');
  }
  
  static void handleGameEnd(String result, String reason) {
    if (kDebugMode) {
      print('Game ended: $result');
      print('Reason: $reason');
    }
    
    // TODO: 添加游戏结束处理逻辑
  }
  
  static void handleStateChange(String oldState, String newState) {
    if (kDebugMode) {
      print('State changed from $oldState to $newState');
    }
    
    // TODO: 添加状态变化处理逻辑
  }
  
  static void handleEngineError(String error) {
    handleError('Engine error: $error');
    
    // TODO: 添加引擎错误恢复逻辑
  }
}

class GameErrorRecovery {
  static const int MAX_RETRY_ATTEMPTS = 3;
  static final Map<String, int> _retryCount = {};
  
  static Future<T> withRetry<T>(
    Future<T> Function() operation,
    String operationKey, {
    int maxAttempts = MAX_RETRY_ATTEMPTS,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      _retryCount[operationKey] = (_retryCount[operationKey] ?? 0) + 1;
      
      if (_retryCount[operationKey]! >= maxAttempts) {
        GameEventHandler.handleError(
          'Maximum retry attempts reached for $operationKey',
          stackTrace: stackTrace,
        );
        rethrow;
      }
      
      // 指数退避重试
      await Future.delayed(
        Duration(milliseconds: 200 * _retryCount[operationKey]!),
      );
      
      return withRetry(operation, operationKey, maxAttempts: maxAttempts);
    }
  }
  
  static void resetRetryCount(String operationKey) {
    _retryCount.remove(operationKey);
  }
  
  /// 恢复游戏状态
  static Future<bool> recoverGameState(
    String lastValidState,
    Function(String) stateRestoreFunction,
  ) async {
    try {
      await stateRestoreFunction(lastValidState);
      return true;
    } catch (e, stackTrace) {
      GameEventHandler.handleError(
        'Failed to recover game state',
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}