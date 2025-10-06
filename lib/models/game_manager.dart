import 'dart:async';
import 'dart:io';

import 'package:cchess/cchess.dart';
import 'package:engine/engine.dart';
import 'package:charset/charset.dart';

import '../driver/player_driver.dart';
import '../global.dart';
import '../utils/rule_validator.dart';
import '../utils/game_event_handler.dart';
import 'chess_skin.dart';
import 'game_event.dart';
import 'game_setting.dart';
import 'sound.dart';
import 'player.dart';

class GameManager {
  late ChessSkin skin;
  double scale = 1;

  // 当前对局
  ChessManual manual = ChessManual();

  // 算法引擎
  Engine engine = Engine();
  StreamSubscription<EngineMessage>? listener;
  bool engineOK = false;

  // 是否重新请求招法时的强制stop
  bool isStop = false;

  // 是否翻转棋盘
  bool _isFlip = false;
  bool get isFlip => _isFlip;

  void flip() {
    add(GameFlipEvent(!isFlip));
  }

  // 是否锁定(非玩家操作的时候锁定界面)
  bool _isLock = false;
  bool get isLock => _isLock;

  // 选手
  final hands = <Player>[];

  int curHand = 0;

  // 当前着法序号
  int _currentStep = 0;
  int get currentStep => _currentStep;

  int get stepCount => manual.moveCount;

  // 是否将军
  bool get isCheckMate => manual.currentMove?.isCheckMate ?? false;

  // 未吃子着数(半回合数)
  int unEatCount = 0;

  // 回合数
  int round = 0;

  final gameEvent = StreamController<GameEvent>();
  final Map<GameEventType, List<void Function(GameEvent)>> listeners = {};

  // 走子规则
  late ChessRule rule;

  late GameSetting setting;

  static GameManager? _instance;

  static GameManager get instance => _instance ??= GameManager();

  GameManager._() {
    gameEvent.stream.listen(_onGameEvent);
  }

  factory GameManager() {
    _instance ??= GameManager._();
    return _instance!;
  }

  Future<bool> init() async {
    rule = ChessRule(manual.currentFen);

    hands.add(Player('r', this, title: manual.red));
    hands.add(Player('b', this, title: manual.black));
    curHand = 0;
    // map = ChessMap.fromFen(ChessManual.startFen);

    setting = await GameSetting.getInstance();

    skin = ChessSkin("woods", this);
    skin.readyNotifier.addListener(() {
      add(GameLoadEvent(0));
    });

    try {
      await engine.init(setting.info);
    } catch (_) {}

    listener = engine.listen(parseMessage);

    return true;
  }

  void on<T extends GameEvent>(void Function(GameEvent) listener) {
    final type = GameEvent.eventType(T);
    if (type == null) {
      logger.warning('type not match ${T.runtimeType}');
      return;
    }
    if (!listeners.containsKey(type)) {
      listeners[type] = [];
    }
    listeners[type]!.add(listener);
  }

  void off<T extends GameEvent>(void Function(GameEvent) listener) {
    final type = GameEvent.eventType(T);
    if (type == null) {
      logger.warning('type not match ${T.runtimeType}');
      return;
    }
    listeners[type]?.remove(listener);
  }

  void add<T extends GameEvent>(T event) {
    gameEvent.add(event);
  }

  void clear() {
    listeners.clear();
  }

  void _onGameEvent(GameEvent e) {
    if (e.type == GameEventType.lock) {
      _isLock = e.data;
    }
    if (e.type == GameEventType.flip) {
      _isFlip = e.data;
    }
    if (listeners.containsKey(e.type)) {
      for (var func in listeners[e.type]!) {
        func.call(e);
      }
    }
  }

  bool get canBacktrace => player.canBacktrace;

  ChessFen get fen => manual.currentFen;

  /// not last but current
  String get lastMove => manual.currentMove?.move ?? '';

  void parseMessage(EngineMessage message) {
    String tMessage = message.message;
    switch (message.type) {
      case MessageType.uciok:
      case MessageType.readyok:
        engineOK = true;
        add(GameEngineEvent('Engine is OK!'));
        break;
      case MessageType.nobestmove:
        // 强行stop后的nobestmove忽略
        if (isStop) {
          isStop = false;
          return;
        }
        break;
      case MessageType.bestmove:
        tMessage = parseBaseMove(tMessage.trim().split(' '));
        break;
      case MessageType.info:
        tMessage = parseInfo(tMessage.trim().split(' '));
        break;
      case MessageType.id:
      case MessageType.option:
      default:
        return;
    }
    add(GameEngineEvent(tMessage));
  }

  String parseBaseMove(List<String> infos) {
    if (infos.isEmpty) {
      return '';
    }
    return "推荐着法: ${fen.toChineseString(infos[0])}"
        "${infos.length > 2 ? ' 对方应招: ${fen.toChineseString(infos[2])}' : ''}";
  }

  String parseInfo(List<String> infos) {
    String first = infos.removeAt(0);
    switch (first) {
      case 'depth':
        String msg = infos.removeAt(0);
        if (infos.isNotEmpty) {
          String sub = infos.removeAt(0);
          while (sub.isNotEmpty) {
            if (sub == 'score') {
              String score = infos.removeAt(0);
              msg += '(${score.contains('-') ? '' : '+'}$score)';
            } else if (sub == 'pv') {
              msg += fen.toChineseTree(infos).join(' ');
              break;
            }
            if (infos.isEmpty) break;
            sub = infos.removeAt(0);
          }
        }
        return msg;
      case 'time':
        return '耗时：${infos[0]}(ms)${infos.length > 2 ? ' 节点数 ${infos[2]}' : ''}';
      case 'currmove':
        return '当前招法: ${fen.toChineseString(infos[0])}${infos.length > 2 ? ' ${infos[2]}' : ''}';
      case 'message':
      default:
        return infos.join(' ');
    }
  }

  void stop() {
    add(GameLoadEvent(-1));
    isStop = true;
    engine.stop();
    //currentStep = 0;

    add(GameLockEvent(true));
  }

  void newGame({
    DriverType amyType = DriverType.user,
    int hand1 = 0,
    String fen = ChessManual.startFen,
  }) {
    stop();

    add(GameStepEvent('clear'));
    add(GameEngineEvent('clear'));
    manual.initFen(fen);
    rule = ChessRule(manual.currentFen);

    // 彻底重建hands，防止driver失效
    for (var p in hands) {
      p.dispose();
    }
    hands.clear();
    hands.add(Player('r', this, title: manual.red));
    hands.add(Player('b', this, title: manual.black));
    if (hand1 == 1) {
      hands[0].driverType = amyType;
      hands[1].driverType = DriverType.user;
    } else {
      hands[0].driverType = DriverType.user;
      hands[1].driverType = amyType;
    }

    curHand = manual.startHand;
    _currentStep = 0;
    unEatCount = 0;

    add(GameLoadEvent(0));
    next();
  }

  void loadPGN(String pgn) {
    stop();

    _loadPGN(pgn);
    add(GameLoadEvent(0));
    next();
  }

  bool _loadPGN(String pgn) {
    isStop = true;
    engine.stop();

    String content = '';
    if (!pgn.contains('\n')) {
      File file = File(pgn);
      if (file.existsSync()) {
        //content = file.readAsStringSync(encoding: Encoding.getByName('gbk'));
        content = gbk.decode(file.readAsBytesSync());
      }
    } else {
      content = pgn;
    }
    manual = ChessManual.load(content);

    hands[0].title = manual.red;
    hands[1].title = manual.black;

    add(GameLoadEvent(0));
    // 加载步数
    if (manual.moveCount > 0) {
      add(
        GameStepEvent(
          manual.moves.map<String>((e) => e.toChineseString()).join('\n'),
        ),
      );
    }
    manual.loadHistory(-1);
    rule.fen = manual.currentFen;
    add(GameStepEvent('step'));

    curHand = manual.startHand;
    return true;
  }

  void loadFen(String fen) {
    newGame(fen: fenStr);
  }

  // 重载历史局面
  void loadHistory(int index) {
    if (index >= manual.moveCount) {
      logger.info('History error');
      return;
    }
    if (index == _currentStep) {
      logger.info('History no change');
      return;
    }
    logger.info('loadHistory called: index=$index, manual.currentStep=${manual.currentStep}, _currentStep=$_currentStep');
    _currentStep = index;
    manual.loadHistory(index);
    rule.fen = manual.currentFen;
    curHand = (_currentStep + 1) % 2;
    add(GamePlayerEvent(curHand));
    add(GameLoadEvent(_currentStep + 1));

    logger.info('history $_currentStep');
  }

  /// 切换驱动
  void switchDriver(int team, DriverType driverType) {
    logger.info('切换驱动 $team ${driverType.name}');
    hands[team].driverType = driverType;

    if (driverType == DriverType.user) {
      //add(GameLockEvent(false));
    } else {
      next();
    }
  }

  /// 调用对应的玩家开始下一步
  Future<void> next() async {
    // 请求提示
    requestHelp();

    final move = await player.move();
    if (move == null) return;

    addMove(move);
    final canNext = checkResult(curHand == 0 ? 1 : 0, _currentStep - 1);
    logger.info('canNext $canNext');
    if (canNext) {
      switchPlayer();
    }
  }

  /// 从用户落着 TODO 检查出发点是否有子，检查落点是否对方子
  void addStep(ChessPos from, ChessPos next) async {
    player.completeMove(PlayerAction(move: '${from.toCode()}${next.toCode()}'));
  }

  void addMove(PlayerAction action) {
    String? move;
    try {
      logger.info('addmove $action');
      move = action.move;
      if (action.type != PlayerActionType.rstMove) {
        if (action.type == PlayerActionType.rstGiveUp) {
          setResult(
            curHand == 0 ? ChessManual.resultFstLoose : ChessManual.resultFstWin,
            '${player.title}认输',
          );
        }
        if (action.type == PlayerActionType.rstDraw) {
          setResult(ChessManual.resultFstDraw);
        }
        if (action.type == PlayerActionType.rstRetract) {
          // todo 悔棋
        }
        if (action.type == PlayerActionType.rstRqstDraw) {
          // todo 和棋
        }
      }
      
      if (move != null && move.isNotEmpty) {
        // 使用 RuleValidator 验证移动
        if (!RuleValidator.validateMove(rule, move, curHand)) {
          GameEventHandler.handleInvalidMove(move, '非法移动');
          return;
        }
        
        // 检查重复局面
        if (RuleValidator.validateRepeatedPosition(manual.moves.map((m) => m.move).toList(), RuleValidator.MAX_REPEATED_MOVES)) {
          GameEventHandler.handleGameEnd('重复局面', '达到最大重复次数');
          setResult(ChessManual.resultFstDraw, '重复局面判和');
          return;
        }
      }
    } catch (e, stackTrace) {
      GameEventHandler.handleError('Error in addMove', stackTrace: stackTrace);
    }
    if (move == null || move.isEmpty) {
      return;
    }

    if (!ChessManual.isPosMove(move)) {
      logger.info('着法错误 $move');
      return;
    }

    // 如果当前不是最后一步，移除后面着法
    if (!manual.isLast) {
      add(GameLoadEvent(-2));
      add(GameStepEvent('clear'));
      manual.addMove(move, addStep: _currentStep);
    } else {
      add(GameLoadEvent(-2));
      manual.addMove(move);
    }
    _currentStep = manual.currentStep;

    final curMove = manual.currentMove!;

    // 优先处理吃子且将军的情况
    if (curMove.isCheckMate && curMove.isEat) {
      unEatCount = 0;
      Sound.play(Sound.check);
      add(GameResultEvent('check'));
    } else if (curMove.isCheckMate) {
      unEatCount++;
      Sound.play(Sound.check);
      add(GameResultEvent('check'));
    } else if (curMove.isEat) {
      unEatCount = 0;
      Sound.play(Sound.capture);
      add(GameResultEvent('eat'));
    } else {
      unEatCount++;
      Sound.play(Sound.move);
    }

    add(GameStepEvent(curMove.toChineseString()));
  }

  void setResult(String result, [String description = '']) {
    if (!ChessManual.results.contains(result)) {
      logger.info('结果不合法 $result');
      return;
    }
    logger.info('本局结果：$result');
    add(GameResultEvent('$result $description'));
    if (result == ChessManual.resultFstDraw) {
      Sound.play(Sound.draw);
    } else if (result == ChessManual.resultFstWin) {
      Sound.play(Sound.win);
    } else if (result == ChessManual.resultFstLoose) {
      Sound.play(Sound.loose);
    }
    manual.result = result;
  }

  /// 棋局结果判断
  bool checkResult(int hand, int curMove) {
    try {
      logger.info('checkResult');

      int repeatRound = manual.repeatRound();
      if (repeatRound > RuleValidator.MAX_REPEATED_MOVES - 1) {
        GameEventHandler.handleGameEnd('重复着法', '即将达到最大重复次数');
      }

      // 判断和棋
      if (unEatCount >= RuleValidator.MAX_MOVES_WITHOUT_CAPTURE) {
        GameEventHandler.handleGameEnd('和棋', '达到最大无吃子着数');
        setResult(ChessManual.resultFstDraw, '60回合无吃子判和');
        return false;
      }

      // 检查长将（先打印最近窗口的走子和吃子信息以便调试）
      try {
        final allMoves = manual.moves.map((m) => m.move).toList();
        int start = (allMoves.length - 6) < 0 ? 0 : allMoves.length - 6;
        final window = allMoves.sublist(start);
        final windowInfo = manual.moves
            .sublist(start)
            .map((m) => '${m.move}${m.isEat ? '(eat)' : ''}')
            .toList();
        logger.info('Perpetual-check debug: windowMoves=$window');
        logger.info('Perpetual-check debug: windowInfo=$windowInfo');
        logger.info('Perpetual-check debug: unEatCount=$unEatCount');

        if (RuleValidator.validatePerpetualCheck(
          allMoves,
          rule,
          unEatCount: unEatCount,
        )) {
          GameEventHandler.handleGameEnd('长将', '连续将军超过限制');
          logger.info('Perpetual-check: triggered, windowInfo=$windowInfo');
          setResult(
            hand == 0 ? ChessManual.resultFstLoose : ChessManual.resultFstWin,
            '长将判负',
          );
          return false;
        }
      } catch (e, st) {
        logger.warning('Perpetual-check debug failed', e, st);
      }

      // 判断输赢，包括能否应将，长将
      final moveStep = manual.currentMove!;
      logger.info('是否将军 ${moveStep.isCheckMate}');

      if (moveStep.isCheckMate) {
        // mover delivered a check to opponent
        int opponent = hand == 0 ? 1 : 0;
        bool opponentCanParry = rule.canParryKill(opponent);
        if (!opponentCanParry) {
          // 绝杀：对方无法应将，直接判胜
          GameEventHandler.handleGameEnd('绝杀', '对方无应将方法');
          // 显示大 '绝杀' 图标
          add(GameResultEvent('kill'));
          // 播放胜利音效
          Sound.play(Sound.win);
          // 延迟弹出胜负提示，确保动画和音效先展示
          Future.delayed(const Duration(seconds: 1), () {
            setResult(
              hand == 0 ? ChessManual.resultFstWin : ChessManual.resultFstLoose,
              '绝杀',
            );
          });
          return false;
        } else {
          // 对方有应将方法：显示大 '将' 字并播放警告音，等待对方应将
          Sound.play(Sound.check);
          add(GameResultEvent('check'));
        }
      } else {
        if (rule.isTrapped(hand)) {
          setResult(
            hand == 0 ? ChessManual.resultFstLoose : ChessManual.resultFstWin,
            '困毙',
          );
          return false;
        } else if (moveStep.isEat) {
          add(GameResultEvent('eat'));
        }
      }

      // TODO 判断长捉，一捉一将，一将一杀
      if (repeatRound > 3) {
        setResult(ChessManual.resultFstDraw, '不变招判和');
        return false;
      }

      return true;
    } catch (e, stackTrace) {
      GameEventHandler.handleError('Error in checkResult', stackTrace: stackTrace);
      return false;
    }
  }

  List<String> getSteps() {
    return manual.moves.map<String>((cs) => cs.toChineseString()).toList();
  }

  void dispose() {
    listener?.cancel();
    engine.stop();
    engine.quit();
    hands.map((e) => e.dispose());
  }

  void switchPlayer() {
    curHand++;
    if (curHand >= hands.length) {
      curHand = 0;
    }
    add(GamePlayerEvent(curHand));

    logger.info('切换选手: $curHand ${player.title} ${player.driverType.name}');

    logger.info(player.title);
    next();
    add(GameEngineEvent('clear'));
  }

  Future<bool> startEngine() {
    return engine.init(setting.info);
  }

  void requestHelp() async {
    if (engine.started) {
      logger.info('manager($hashCode) requested help');
      isStop = true;
      await engine.stop();
      engine.position(fenStr);
      await engine.go(depth: 10);
    } else {
      logger.info('engine is not started');
    }
  }

  String get fenStr => '${manual.currentFen.fen} ${curHand > 0 ? 'b' : 'w'}'
      ' - - $unEatCount ${manual.moveCount ~/ 2}';

  Player get player => hands[curHand];

  Player getPlayer(int hand) => hands[hand];

  /// 是否可以悔棋（至少有一步可以回退）
  bool canRetract() {
    return manual.moveCount > 0 && _currentStep > 0;
  }

  /// 直接回退一步（本地/人机模式使用）
  /// 注意：此方法不会与对手交互同意流程，适用于本地双方或自动接受的机器人
  void retract() {
    // 同步内部当前索引与 manual，确保基于最新位置退一步
    _currentStep = manual.currentStep;
    if (!canRetract()) return;

    // 停止引擎计算，准备回滚
    try {
      engine.stop();
    } catch (_) {}

    // 以 _currentStep 为准，向后退一步
    int target = _currentStep - 1;
    logger.info('retract called: synced _currentStep=$_currentStep, manual.currentStep=${manual.currentStep}, manual.moveCount=${manual.moveCount}, computed target=$target');
    if (target < 0) target = 0;

    // 使用已有的历史加载逻辑完成回滚
    manual.loadHistory(target);
    rule.fen = manual.currentFen;
    _currentStep = target;
    // 回退后行棋方为 (currentStep+1)%2
    curHand = (_currentStep + 1) % 2;

    // 重新计算未吃子计数
    _recomputeUnEatCount();

    // 通知界面和玩家
    add(GamePlayerEvent(curHand));
    add(GameLoadEvent(_currentStep + 1));
    if (manual.currentMove != null) {
      add(GameStepEvent(manual.currentMove!.toChineseString()));
    } else {
      add(GameStepEvent(''));
    }

    // 让引擎重新定位到新的局面
    try {
      engine.position(fenStr);
    } catch (_) {}
  }

  void _recomputeUnEatCount() {
    int cnt = 0;
    for (int i = manual.moves.length - 1; i >= 0; i--) {
      if (manual.moves[i].isEat) {
        break;
      }
      cnt++;
    }
    unEatCount = cnt;
  }

  /// 发起悔棋请求：向对手驱动询问是否同意
  /// 若对方同意则执行实际回退并返回 true，否则返回 false
  Future<bool> requestRetract() async {
    if (!canRetract()) return Future.value(false);

    int opponent = curHand == 0 ? 1 : 0;

    // 同步当前步数，计算上一步是谁
    _currentStep = manual.currentStep;
    int lastMover = _currentStep - 1;
    if (lastMover < 0) lastMover = 0;

    try {
      logger.info('requestRetract: curHand=$curHand, opponent=$opponent, manual.currentStep=${manual.currentStep}, lastMover=$lastMover');
      // 询问对手驱动是否同意悔棋
      bool agree = await hands[opponent].driver.tryRetract();
      if (agree) {
        // 判断是否需要撤回两步：如果最后一步是机器人走的，且另一方是用户，则撤两步以回到用户行棋前的局面
        bool lastWasRobot = hands[lastMover].isRobot;
        bool otherIsUser = hands[1 - lastMover].isUser;

        // 首次回退
        retract();

        if (lastWasRobot && otherIsUser && canRetract()) {
          logger.info('requestRetract: lastWasRobot && otherIsUser -> performing second retract');
          retract();
        }

        add(GameResultEvent('retract accepted'));
        return true;
      } else {
        add(GameResultEvent('retract rejected'));
        return false;
      }
    } catch (e, st) {
      GameEventHandler.handleError('Error in requestRetract', stackTrace: st);
      return false;
    }
  }

  /// 发起求和请求：向对手驱动询问是否接受和棋
  /// 若对方同意则设为和棋并返回 true，否则返回 false
  Future<bool> offerDraw() async {
    int opponent = curHand == 0 ? 1 : 0;
    try {
      // 询问对手驱动是否同意和棋
      bool accept = await hands[opponent].driver.tryDraw();
      if (accept) {
        setResult(ChessManual.resultFstDraw, '双方和棋');
        add(GameResultEvent('draw accepted'));
        return true;
      } else {
        add(GameResultEvent('draw rejected'));
        return false;
      }
    } catch (e, st) {
      GameEventHandler.handleError('Error in offerDraw', stackTrace: st);
      return false;
    }
  }

  /// 本方认输（直接结束对局，记录结果）
  void resign() {
    // 本方认输：当前行棋方放弃
    setResult(curHand == 0 ? ChessManual.resultFstLoose : ChessManual.resultFstWin,
        '${player.title}认输');
  }
}
