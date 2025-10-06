import 'dart:async';

import '../models/game_event.dart';

import 'player_driver.dart';

class DriverUser extends PlayerDriver {
  late Completer<PlayerAction> requestMove;

  DriverUser(super.player);

  @override
  Future<bool> tryDraw() {
    return Future.value(true);
  }

  @override
  Future<PlayerAction?> move() {
    requestMove = Completer<PlayerAction>();
    player.manager.add(GameLockEvent(false));

    return requestMove.future;
  }

  @override
  Future<String> ponder() {
    // TODO: implement ponder
    throw UnimplementedError();
  }

  @override
  void completeMove(PlayerAction move) {
    if (!requestMove.isCompleted) {
      requestMove.complete(move);
    }
  }

  @override
  Future<bool> tryRetract() {
    // 本地用户驱动默认由界面协商（Chess 组件会弹窗），此处直接返回 true 表示请求已发出
    return Future.value(true);
  }

  @override
  Future<void> init() async {}
  @override
  Future<void> dispose() async {}
}
