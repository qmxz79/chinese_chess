import 'package:flutter/material.dart';
import '../pages/home_page.dart';
import '../pages/game_page.dart';
import '../pages/settings_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String game = '/game';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> routes = {
    home: (context) => const HomePage(),
    game: (context) => const GamePage(),
    settings: (context) => const SettingsPage(),
  };
}