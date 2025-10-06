import 'package:flutter/material.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../models/game_manager.dart';
import '../global.dart';
import '../models/play_mode.dart';
import 'play_step.dart';

class GameBottomBar extends StatefulWidget {
  final PlayMode mode;

  const GameBottomBar(this.mode, {super.key});

  @override
  State<GameBottomBar> createState() => GameBottomBarState();
}

class GameBottomBarState extends State<GameBottomBar> {
  final GameManager gamer = GameManager.instance;

  @override
  Widget build(BuildContext context) {
    if (widget.mode == PlayMode.modeRobot) {
      return robotBottomBar();
    }
    if (widget.mode == PlayMode.modeRobot) {
      return onlineBottomBar();
    }

    return freeBottomBar();
  }

  void _showStepList() {
    final size = MediaQuery.of(context).size;
    MyDialog.popup(
      SizedBox(
        height: size.height * 0.75,
        child: Center(
          child: PlayStep(
            width: size.width * 0.8,
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showCode() {}

  void _doReply() {}

  void _doRetract() {
    if (!gamer.canRetract()) return;

    // debug log
    logger.info('ui requestRetract: gamer.currentStep=${gamer.currentStep}, manual.moveCount=${gamer.manual.moveCount}');

    // 发起悔棋请求（会根据驱动策略进行协商）
    gamer.requestRetract().then((accepted) {
      if (accepted) {
        // 撤回已执行
        setState(() {});
      } else {
        // 通知用户被拒绝
        // 使用简单的对话或 snackbar，PlayPage/Wrapper 可识别
      }
    });
  }

  void _doOfferDraw() {
    gamer.offerDraw().then((accepted) {
      if (accepted) {
        setState(() {});
      } else {
        // 提和被拒绝
      }
    });
  }

  void _doResign() {
    gamer.resign();
    setState(() {});
  }

  void _goPrev() {
    if (gamer.currentStep < 1) return;
    gamer.loadHistory(gamer.currentStep - 1);
    setState(() {});
  }

  void _goNext() {
    if (gamer.currentStep + 1 >= gamer.stepCount) return;
    gamer.loadHistory(gamer.currentStep + 1);
    setState(() {});
  }

  Widget freeBottomBar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.list), onPressed: _showStepList),
          IconButton(icon: const Icon(Icons.undo), onPressed: _doRetract),
          IconButton(icon: const Icon(Icons.pan_tool), onPressed: _doOfferDraw, tooltip: '求和'),
          IconButton(icon: const Icon(Icons.flag), onPressed: _doResign, tooltip: '认输'),
          IconButton(icon: const Icon(Icons.code), onPressed: _showCode),
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: _goPrev,
          ),
          IconButton(icon: const Icon(Icons.navigate_next), onPressed: _goNext),
        ],
      ),
    );
  }

  Widget onlineBottomBar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.list), onPressed: _showStepList),
          IconButton(icon: const Icon(Icons.replay), onPressed: _doReply),
          IconButton(icon: const Icon(Icons.undo), onPressed: _doRetract),
          IconButton(icon: const Icon(Icons.pan_tool), onPressed: _doOfferDraw, tooltip: '求和'),
          IconButton(icon: const Icon(Icons.flag), onPressed: _doResign, tooltip: '认输'),
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: _goPrev,
          ),
          IconButton(icon: const Icon(Icons.navigate_next), onPressed: _goNext),
        ],
      ),
    );
  }

  Widget robotBottomBar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.list), onPressed: _showStepList),
          IconButton(icon: const Icon(Icons.replay), onPressed: _doReply),
          IconButton(icon: const Icon(Icons.undo), onPressed: _doRetract),
          IconButton(icon: const Icon(Icons.pan_tool), onPressed: _doOfferDraw, tooltip: '求和'),
          IconButton(icon: const Icon(Icons.flag), onPressed: _doResign, tooltip: '认输'),
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: _goPrev,
          ),
          IconButton(icon: const Icon(Icons.navigate_next), onPressed: _goNext),
        ],
      ),
    );
  }
}
