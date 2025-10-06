import 'package:engine/engine.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import 'global.dart';
import 'models/game_setting.dart';

/// 设置页
class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  GameSetting? setting;

  @override
  void initState() {
    super.initState();
    GameSetting.getInstance().then(
      (value) => setState(() {
        setting = value;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    double width = 500;
    if (MediaQuery.of(context).size.width < width) {
      width = MediaQuery.of(context).size.width;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingTitle),
        actions: [
          TextButton(
            onPressed: () {
              setting?.save().then((v) {
                Navigator.pop(context);
                MyDialog.toast('保存成功', iconType: IconType.success);
              });
            },
            child: const Text(
              '保存',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Center(
        child: setting == null
            ? const CircularProgressIndicator()
            : Container(
                width: width,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: ListBody(
                    children: [
                      ListTile(
                        title: const Text('AI类型'),
                        trailing: DropdownButton<String>(
                          value: Engine()
                              .getSupportedEngines()
                              .map((e) => e.name)
                              .contains(setting!.info.name)
                              ? setting!.info.name
                              : builtInEngine.name,
                          items: [
                            builtInEngine.name,
                            ...Engine().getSupportedEngines().map((e) => e.name),
                          ]
                              .map((name) => DropdownMenuItem(
                                    value: name,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: Text(name),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              final engine = Engine()
                                  .getSupportedEngines()
                                  .firstWhere(
                                    (e) => e.name == v,
                                    orElse: () => builtInEngine,
                                  );
                              setting!.info = engine;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('AI级别'),
                        trailing: DropdownButton<int>(
                          value: [2, 3, 4, 5, 6].contains(setting!.engineLevel)
                              ? setting!.engineLevel
                              : 3,
                          items: const [
                            DropdownMenuItem(value: 2, child: Text('入门')),
                            DropdownMenuItem(value: 3, child: Text('初级')),
                            DropdownMenuItem(value: 4, child: Text('中级')),
                            DropdownMenuItem(value: 5, child: Text('高级')),
                            DropdownMenuItem(value: 6, child: Text('大师')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              setting!.engineLevel = v;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('游戏声音'),
                        trailing: CupertinoSwitch(
                          value: setting!.sound,
                          onChanged: (v) {
                            setState(() {
                              setting!.sound = v;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('游戏音量'),
                        trailing: CupertinoSlider(
                          value: setting!.soundVolume,
                          min: 0,
                          max: 1,
                          onChanged: (v) {
                            setState(() {
                              setting!.soundVolume = v;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
