import '../models/game_event.dart';
import 'player_driver.dart';

class DriverOnline extends PlayerDriver {
  DriverOnline(super.player) {
    canBacktrace = false;
  }

  @override
  Future<void> init() async {}
  @override
  Future<void> dispose() async {}

  @override
  Future<bool> tryDraw() {
    return Future.value(true);
  }

  @override
  Future<PlayerAction?> move() {
    player.manager.add(GameLockEvent(true));
    throw UnimplementedError();
  }

  @override
  Future<String> ponder() {
    throw UnimplementedError();
  }

  @override
  void completeMove(PlayerAction move) {
    throw UnimplementedError();
  }

  @override
  Future<bool> tryRetract() {
    // 在线模式默认不允许本地直接悔棋，应通过网络协议协商
    return Future.value(false);
  }
}
