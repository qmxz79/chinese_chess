import 'package:cchess/cchess.dart';

class AIStrategy {
  static const Map<String, int> PIECE_VALUES = {
    'k': 10000, // 将/帅
    'a': 200,   // 士/仕
    'b': 200,   // 象/相
    'n': 400,   // 马
    'r': 900,   // 车
    'c': 450,   // 炮
    'p': 100,   // 兵/卒
  };
  
  /// 局面评估
  static int evaluatePosition(ChessFen fen, int team) {
    int score = 0;
    List<ChessItem> pieces = fen.getAll();
    
    for (var piece in pieces) {
      int value = PIECE_VALUES[piece.code.toLowerCase()] ?? 0;
      
      // 根据位置调整分值
      value += _getPositionBonus(piece);
      
      // 根据是否被保护调整分值
      value += _getProtectionBonus(piece, fen);
      
      score += piece.team == team ? value : -value;
    }
    
    return score;
  }
  
  /// 获取位置加成
  static int _getPositionBonus(ChessItem piece) {
    int bonus = 0;
    
    // 中间位置加成
    if (piece.position.x >= 3 && piece.position.x <= 5) {
      bonus += 10;
    }
    
    // 根据不同棋子类型给予不同的位置加成
    switch (piece.code.toLowerCase()) {
      case 'p': // 兵/卒
        // 过河加成
        if ((piece.team == 0 && piece.position.y > 4) ||
            (piece.team == 1 && piece.position.y < 5)) {
          bonus += 50;
        }
        break;
      case 'n': // 马
        // 靠近中心加成
        if (piece.position.x >= 2 && piece.position.x <= 6) {
          bonus += 20;
        }
        break;
      case 'c': // 炮
        // 炮架位置加成
        if (piece.position.y == 1 || piece.position.y == 8) {
          bonus += 30;
        }
        break;
    }
    
    return bonus;
  }
  
  /// 获取保护加成
  static int _getProtectionBonus(ChessItem piece, ChessFen fen) {
    int bonus = 0;
    ChessRule rule = ChessRule(fen);
    // 计算保护该子的棋子数量（部分 cchess 版本可能没有直接 API），
    // 使用 movePoints 扫描对方能否吃到本子来估算保护数
    List<ChessItem> protectors = [];
    // 计算该子可以保护的棋子数量
    List<String> moves = rule.movePoints(piece.position);
    for (var move in moves) {
      ChessPos pos = ChessPos.fromCode(move);
      String targetChr = fen[pos.y][pos.x];
      if (targetChr != '0') {
        // 判断目标棋子是否同队
        // cchess uses uppercase/lowercase to denote team
        bool sameTeam = (piece.team == 0)
            ? targetChr.toUpperCase() == targetChr
            : targetChr.toLowerCase() == targetChr;
        if (sameTeam) {
          bonus += 20;
        }
      }
    }
    bonus += protectors.length * 30;
    
    return bonus;
  }
  
  /// 获取最佳移动
  /// [level] 控制AI搜索深度，默认10，越大越强
  static String getBestMove(ChessFen fen, int team, List<String> legalMoves, {int level = 10}) {
    String bestMove = legalMoves[0];
    int bestScore = -99999;
  int searchDepth = level.clamp(2, 6); // 允许2~6层，防止卡死
    for (var move in legalMoves) {
      ChessRule rule = ChessRule(fen.copy());
      rule.fen.move(move);
      int score = _minimax(rule.fen, team, searchDepth - 1, false);
      // 保留原有加分逻辑
      int enemy = team == 0 ? 1 : 0;
      if (rule.teamCanCheck(enemy)) {
        List<String> checkMoves = rule.getCheckMoves(enemy);
        bool hasParry = false;
        for (var cm in checkMoves) {
          ChessRule er = ChessRule(rule.fen.copy());
          er.fen.move(cm);
          if (!er.canParryKill(team)) {
            hasParry = true;
            break;
          }
        }
        if (!hasParry) score += 500;
      }
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    return bestMove;
  }

  /// 简单极小极大搜索，level 控制递归层数
  static int _minimax(ChessFen fen, int team, int depth, bool maximizing) {
    if (depth == 0) {
      return evaluatePosition(fen, team);
    }
    ChessRule rule = ChessRule(fen);
    int searchTeam = maximizing ? team : 1 - team;
    List<String> moves = [];
    for (var item in fen.getAll()) {
      if (item.team == searchTeam) {
        moves.addAll(rule.movePoints(item.position).map((to) => item.position.toCode() + to));
      }
    }
    if (moves.isEmpty) {
      return maximizing ? -99999 : 99999;
    }
    int best = maximizing ? -99999 : 99999;
    for (var move in moves) {
      ChessRule nextRule = ChessRule(fen.copy());
      nextRule.fen.move(move);
      int score = _minimax(nextRule.fen, team, depth - 1, !maximizing);
      if (maximizing) {
        if (score > best) best = score;
      } else {
        if (score < best) best = score;
      }
    }
    return best;
  }
}