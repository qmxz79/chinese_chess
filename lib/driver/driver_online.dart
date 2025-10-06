import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/game_event.dart';
import 'player_driver.dart';
import '../global.dart';

/// A lightweight online driver that connects to a WebSocket relay server.
/// Protocol (JSON): { "type": "join" | "move" | "retract" | "draw" | "resign", "payload": {...} }
class DriverOnline extends PlayerDriver {
  DriverOnline(super.player) {
    canBacktrace = false;
  }

  WebSocketChannel? _channel;
  late StreamSubscription _sub;
  final _incoming = StreamController<PlayerAction?>();
  Completer<PlayerAction>? _pendingMove;

  String? _roomId;

  Future<void> _connect(String uri) async {
    _channel = WebSocketChannel.connect(Uri.parse(uri));
    _sub = _channel!.stream.listen(_onMessage, onDone: _onDone, onError: _onError);
  }

  void _onMessage(dynamic msg) {
    try {
      final m = json.decode(msg as String) as Map<String, dynamic>;
      final type = m['type'] as String?;
      final payload = m['payload'] as Map<String, dynamic>?;

      switch (type) {
        case 'joined':
          // server assigned room
          _roomId = payload?['roomId'];
          logger.info('DriverOnline joined room: $_roomId');
          // notify UI about connection
          try {
            player.manager.add(GameResultEvent('online:connected:${_roomId ?? ''}'));
          } catch (_) {}
          break;
        case 'move':
          final move = payload?['move'] as String?;
          if (move != null) {
            // Opponent move arrived
            _incoming.add(PlayerAction(move: move));
          }
          break;
        case 'rq_retract':
          // opponent requested a retract; notify UI via game event
          player.manager.add(GameResultEvent('incoming_request:retract'));
          break;
        case 'retract':
          // opponent accepted a retract request
          _incoming.add(PlayerAction(type: PlayerActionType.rstRetract));
          break;
        case 'reject_retract':
          _incoming.add(PlayerAction(type: PlayerActionType.rjctRetract));
          break;
        case 'rq_draw':
          player.manager.add(GameResultEvent('incoming_request:draw'));
          break;
        case 'draw':
          _incoming.add(PlayerAction(type: PlayerActionType.rstDraw));
          break;
        case 'reject_draw':
          _incoming.add(PlayerAction(type: PlayerActionType.rjctDraw));
          break;
        case 'resign':
          _incoming.add(PlayerAction(type: PlayerActionType.rstGiveUp));
          break;
        default:
          break;
      }
    } catch (e) {
      // ignore
    }
  }

  void _onDone() {
    _incoming.add(null);
    try {
      player.manager.add(GameResultEvent('online:disconnected'));
    } catch (_) {}
  }

  void _onError(Object e) {
    _incoming.add(null);
    try {
      player.manager.add(GameResultEvent('online:disconnected'));
    } catch (_) {}
  }

  @override
  Future<void> init() async {
    // connect to local server by default
    try {
      final server = player.manager.setting.onlineServer;
      await _connect(server);
      // send join with requested side info
      _send({'type': 'join', 'payload': {'team': player.team}});
      logger.info('DriverOnline connecting to server for team=${player.team}');
    } catch (e) {
      // connection failed; leave as disconnected
    }
  }

  @override
  Future<void> dispose() async {
    await _incoming.close();
    await _sub.cancel();
    await _channel?.sink.close();
    try {
      player.manager.add(GameResultEvent('online:disconnected'));
    } catch (_) {}
  }

  void _send(Map<String, dynamic> m) {
    try {
      _channel?.sink.add(json.encode(m));
    } catch (e) {
      // swallow
    }
  }

  @override
  Future<bool> tryDraw() async {
    // send draw request to server and wait for opponent response
    final completer = Completer<bool>();
    // protocol: server will forward 'rq_draw' to opponent and reply with 'draw' or 'reject_draw'
    // we listen to _incoming for draw/reject
    final sub = _incoming.stream.listen((action) {
      if (action == null) return;
      if (action.type == PlayerActionType.rstDraw) {
        completer.complete(true);
      } else if (action.type == PlayerActionType.rjctDraw) {
        completer.complete(false);
      }
    });
    _send({'type': 'rq_draw', 'payload': {}});
    final res = await completer.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
    await sub.cancel();
    return res;
  }

  @override
  Future<PlayerAction?> move() {
    // For online mode, we wait for incoming opponent move or user triggered move via completeMove
    _pendingMove = Completer<PlayerAction>();
    // Lock UI while waiting for opponent if it's not our turn
    player.manager.add(GameLockEvent(true));

    // If an opponent move arrives via _incoming, complete the pending move
    final sub = _incoming.stream.listen((action) {
      if (action == null) return;
      if (action.type == PlayerActionType.rstMove && action.move != null) {
        if (!(_pendingMove?.isCompleted ?? true)) {
          _pendingMove?.complete(action);
        }
      } else if (action.type == PlayerActionType.rstRetract) {
        // opponent accepted our retract request -> forward as special action
        if (!(_pendingMove?.isCompleted ?? true)) {
          _pendingMove?.complete(PlayerAction(type: PlayerActionType.rstRetract));
        }
      } else if (action.type == PlayerActionType.rjctRetract) {
        if (!(_pendingMove?.isCompleted ?? true)) {
          _pendingMove?.complete(PlayerAction(type: PlayerActionType.rjctRetract));
        }
      } else if (action.type == PlayerActionType.rstGiveUp) {
        if (!(_pendingMove?.isCompleted ?? true)) {
          _pendingMove?.complete(PlayerAction(type: PlayerActionType.rstGiveUp));
        }
      }
    });

    return _pendingMove!.future.whenComplete(() async {
      await sub.cancel();
    });
  }

  @override
  Future<String> ponder() async {
    // not supported online
    return Future.value('');
  }

  @override
  void completeMove(PlayerAction move) {
    // send move to server for forwarding
    if (move.type == PlayerActionType.rstMove && move.move != null) {
      _send({'type': 'move', 'payload': {'move': move.move}});
    } else if (move.type == PlayerActionType.rstRqstRetract) {
      _send({'type': 'rq_retract', 'payload': {}});
    } else if (move.type == PlayerActionType.rstRqstDraw) {
      _send({'type': 'rq_draw', 'payload': {}});
    } else if (move.type == PlayerActionType.rstGiveUp) {
      _send({'type': 'resign', 'payload': {}});
    }
    // local complete (for user-driven moves) is done by GameManager adding the move
  }

  @override
  Future<bool> tryRetract() async {
    // send retract request to opponent and wait for response
    final completer = Completer<bool>();
    final sub = _incoming.stream.listen((action) {
      if (action == null) return;
      if (action.type == PlayerActionType.rstRetract) {
        completer.complete(true);
      } else if (action.type == PlayerActionType.rjctRetract) {
        completer.complete(false);
      }
    });
    _send({'type': 'rq_retract', 'payload': {}});
    final res = await completer.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
    await sub.cancel();
    return res;
  }

  /// Expose connection state and joined room id
  bool get isConnected => _channel != null;

  String get roomId => _roomId ?? '';

  /// Respond to an incoming request (from remote) such as 'retract' or 'draw'
  /// UI code can call this on the player's driver when user accepts/rejects.
  void respondRequest(String reqType, bool accept) {
    if (reqType == 'retract') {
      _send({'type': accept ? 'retract' : 'reject_retract', 'payload': {}});
    } else if (reqType == 'draw') {
      _send({'type': accept ? 'draw' : 'reject_draw', 'payload': {}});
    }
  }
}
