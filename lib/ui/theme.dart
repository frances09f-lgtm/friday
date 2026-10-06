import 'package:flutter/material.dart';

const fridayAccent = Color(0xFF7C9CFF);
const fridayBg = Color(0xFF0E1013);
const fridaySurface = Color(0xFF181B21);
const fridayUserBubble = Color(0xFF2B3A67);

ThemeData fridayTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: fridayAccent,
    brightness: Brightness.dark,
    surface: fridaySurface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: fridayBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: fridayBg,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: fridaySurface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fridaySurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
