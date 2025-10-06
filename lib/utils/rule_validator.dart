import 'dart:math' as math;
import 'package:cchess/cchess.dart';
import '../global.dart';

class RuleValidator {
  static const int MAX_MOVES_WITHOUT_CAPTURE = 120;
  static const int MAX_REPEATED_MOVES = 3;
  
  /// 验证移动的合法性
  static bool validateMove(ChessRule rule, String move, int team) {
    // 复制一个新的局面进行验证
    ChessRule tempRule = ChessRule(rule.fen.copy());
    tempRule.fen.move(move);
    
    // 检查是否造成王见王
    if (tempRule.isKingMeet(team)) {
      return false;
    }
    
    // 检查是否送将
    if (tempRule.isCheck(team)) {
      return false;
    }
    
    // 检查是否困毙
    if (tempRule.isTrapped(team)) {
      return false;
    }
    
    return true;
  }
  
  /// 验证重复局面
  static bool validateRepeatedPosition(List<String> moves, int maxRepeats) {
    if (moves.length < 4) return false;
    
    // 检查最后几步是否形成循环
    int repeatCount = 0;
    String lastPosition = moves.last;
    
    for (int i = moves.length - 2; i >= 0; i -= 2) {
      if (moves[i] == lastPosition) {
        repeatCount++;
        if (repeatCount >= maxRepeats) {
          return true;
        }
      }
    }
    
    return false;
  }
  
  /// 验证长将
  static bool validatePerpetualCheck(List<String> moves, ChessRule rule,
      {int? unEatCount}) {
    if (moves.length < 6) return false;
    // 统计最近若干着中，每一方实际送将的次数（应用移动后判断对方是否被将军）
    Map<int, int> deliveredChecks = {0: 0, 1: 0};
    int start = math.max(0, moves.length - 6);

    // 如果窗口内有吃子，则不视为纯粹长将，返回 false
    for (int i = start; i < moves.length; i++) {
      try {
        // 检查该着是否为吃子：解析目标格并比较落子前是否为非空
        String mv = moves[i];
        if (mv.length >= 4) {
          final to = ChessPos.fromCode(mv.substring(2, 4));
          ChessFen fenCopy = rule.fen.copy();
          String before = fenCopy[to.y][to.x];
          if (before != '0') {
            logger.fine('RuleValidator: capture detected in window, skip perpetual-check');
            return false;
          }
        }
      } catch (_) {
        // 无法解析视为不触发
        return false;
      }
    }

    for (int i = start; i < moves.length; i++) {
      ChessRule tempRule = ChessRule(rule.fen.copy());
      try {
        // 在拷贝上执行走法
        tempRule.fen.move(moves[i]);
      } catch (_) {
        continue;
      }
      // 计算走子方（假定 moves[0] 为先手红方）
      int moverTeam = (i % 2 == 0) ? 0 : 1;
      int opponent = 1 - moverTeam;
      // 应用该着后，若对方处于将军，则该走子方送了一次将（仅统计非吃子情况）
      try {
        if (tempRule.isCheck(opponent)) {
          deliveredChecks[moverTeam] = (deliveredChecks[moverTeam] ?? 0) + 1;
          logger.info(
            'RuleValidator: delivered check by team=$moverTeam at moveIndex=$i, counts=$deliveredChecks, window=${moves.sublist(start)}',
          );
          if (deliveredChecks[moverTeam]! >= 3) {
            logger.info(
              'RuleValidator: perpetual-check triggered by team=$moverTeam, recentMoves=${moves.sublist(start)}',
            );
            return true;
          }
        }
      } catch (_) {
        // 如果底层库行为异常，忽略该步判定，继续以防误判
      }
    }

    return false;
  }
}
