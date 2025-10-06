class ChessConstants {
  static const initialFEN = 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';
  
  static const boardSize = 9; // 棋盘大小 9x10
  static const boardRows = 10;
  
  static const pieceTypes = {
    'r': '车',
    'n': '马',
    'b': '相',
    'a': '仕',
    'k': '帅',
    'c': '炮',
    'p': '兵',
    'R': '车',
    'N': '马',
    'B': '象',
    'A': '士',
    'K': '将',
    'C': '炮',
    'P': '卒',
  };
  
  static const defaultTheme = 'woods';
  static const defaultLanguage = 'zh';
  
  // 音效
  static const soundMove = 'move.wav';
  static const soundCapture = 'capture.wav';
  static const soundCheck = 'check.wav';
  static const soundGameOver = 'gameover.wav';
}