import 'package:cchess/cchess.dart';
import 'package:chinese_chess/utils/ai_strategy.dart';

class PerformanceOptimizer {
  static const int CACHE_SIZE = 1000;
  static final Map<String, List<String>> _moveCache = {};
  static final Map<String, int> _evaluationCache = {};
  
  /// 缓存移动
  static void cacheMoves(String fenString, List<String> moves) {
    _cleanCacheIfNeeded();
    _moveCache[fenString] = moves;
  }
  
  /// 获取缓存的移动
  static List<String>? getCachedMoves(String fenString) {
    return _moveCache[fenString];
  }
  
  /// 缓存局面评估
  static void cacheEvaluation(String fenString, int evaluation) {
    _cleanCacheIfNeeded();
    _evaluationCache[fenString] = evaluation;
  }
  
  /// 获取缓存的评估值
  static int? getCachedEvaluation(String fenString) {
    return _evaluationCache[fenString];
  }
  
  /// 清理过期缓存
  static void _cleanCacheIfNeeded() {
    if (_moveCache.length > CACHE_SIZE) {
      _moveCache.clear();
    }
    
    if (_evaluationCache.length > CACHE_SIZE) {
      _evaluationCache.clear();
    }
  }
  
  /// 优化移动生成
  static List<String> optimizeMoveGeneration(ChessRule rule, ChessPos position) {
    String fenString = rule.fen.toString() + position.toString();
    
    // 检查缓存
    List<String>? cachedMoves = getCachedMoves(fenString);
    if (cachedMoves != null) {
      return cachedMoves;
    }
    
    // 生成新的移动
    List<String> moves = rule.movePoints(position);
    
    // 缓存结果
    cacheMoves(fenString, moves);
    
    return moves;
  }
  
  /// 优化局面评估
  static int optimizePositionEvaluation(ChessFen fen, int team) {
    String fenString = fen.toString() + team.toString();
    
    // 检查缓存
    int? cachedEvaluation = getCachedEvaluation(fenString);
    if (cachedEvaluation != null) {
      return cachedEvaluation;
    }
    
    // 计算新的评估值
    int evaluation = AIStrategy.evaluatePosition(fen, team);
    
    // 缓存结果
    cacheEvaluation(fenString, evaluation);
    
    return evaluation;
  }
}