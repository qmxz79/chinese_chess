import 'package:shared_preferences/shared_preferences.dart';

class ConfigManager {
  static final ConfigManager _instance = ConfigManager._internal();
  static SharedPreferences? _prefs;

  factory ConfigManager() {
    return _instance;
  }

  ConfigManager._internal();

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get soundEnabled {
    return _prefs?.getBool('sound_enabled') ?? true;
  }

  static set soundEnabled(bool value) {
    _prefs?.setBool('sound_enabled', value);
  }

  static String get language {
    return _prefs?.getString('language') ?? 'zh';
  }

  static set language(String value) {
    _prefs?.setString('language', value);
  }

  static String get theme {
    return _prefs?.getString('theme') ?? 'light';
  }

  static set theme(String value) {
    _prefs?.setString('theme', value);
  }
}