import 'package:flutter/material.dart';
import '../models/game_setting.dart';
import '../global.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late GameSetting setting;
  bool loading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final s = await GameSetting.getInstance();
      if (!mounted) return;
      setState(() {
        setting = s;
        loading = false;
      });
    } catch (e, st) {
      logger.warning('Failed to load settings', e, st);
      if (!mounted) return;
      setState(() {
        loadError = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('加载设置失败：$loadError'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadSetting,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('AI难度', style: TextStyle(fontSize: 18)),
              DropdownButton<int>(
                value: setting.engineLevel,
                items: List.generate(5, (i) => i + 2)
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text('$v'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => setting.engineLevel = v);
                    _safeSave();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('音效', style: TextStyle(fontSize: 18)),
              Switch(
                value: setting.sound,
                onChanged: (v) {
                  setState(() => setting.sound = v);
                  _safeSave();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('音量', style: TextStyle(fontSize: 18)),
              Slider(
                value: setting.soundVolume,
                min: 0,
                max: 1,
                divisions: 10,
                label: (setting.soundVolume * 100).toInt().toString(),
                onChanged: (v) {
                  setState(() => setting.soundVolume = v);
                  _safeSave();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _safeSave() async {
    try {
      await setting.save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    } catch (e, st) {
      logger.warning('Failed to save setting', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：${e.toString()}')),
      );
    }
  }
}
