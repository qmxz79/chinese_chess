import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primaryColor: Colors.red[700],
    colorScheme: ColorScheme.light(
      primary: Colors.red[700]!,
      secondary: Colors.amber[700]!,
    ),
    scaffoldBackgroundColor: Colors.brown[50],
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    primaryColor: Colors.red[900],
    colorScheme: ColorScheme.dark(
      primary: Colors.red[900]!,
      secondary: Colors.amber[900]!,
    ),
    scaffoldBackgroundColor: Colors.brown[900],
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white70,
      ),
    ),
  );
}