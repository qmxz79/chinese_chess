import 'package:flutter/foundation.dart';

enum GameState {
  idle,
  playing,
  paused,
  gameOver
}

class GameStateManager extends ChangeNotifier {
  GameState _state = GameState.idle;
  String? _winner;
  final List<String> _moves = [];

  GameState get state => _state;
  String? get winner => _winner;
  List<String> get moves => List.unmodifiable(_moves);

  void startGame() {
    _state = GameState.playing;
    _winner = null;
    _moves.clear();
    notifyListeners();
  }

  void pauseGame() {
    if (_state == GameState.playing) {
      _state = GameState.paused;
      notifyListeners();
    }
  }

  void resumeGame() {
    if (_state == GameState.paused) {
      _state = GameState.playing;
      notifyListeners();
    }
  }

  void endGame(String? winner) {
    _state = GameState.gameOver;
    _winner = winner;
    notifyListeners();
  }

  void addMove(String move) {
    if (_state == GameState.playing) {
      _moves.add(move);
      notifyListeners();
    }
  }

  void undoLastMove() {
    if (_moves.isNotEmpty && _state != GameState.gameOver) {
      _moves.removeLast();
      notifyListeners();
    }
  }
}