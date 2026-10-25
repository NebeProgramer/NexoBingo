import 'package:flutter/material.dart';

/// Paleta visual de NexoBingo (port de `UI/Theme.java`): sala de juegos
/// nocturna con acentos dorados.
abstract final class AppColors {
  static const bgDark = Color(0xFF101823);
  static const bgPanel = Color(0xFF18233A);
  static const bgCard = Color(0xFF1F2C47);
  static const border = Color(0xFF2C3B5C);

  static const gold = Color(0xFFF2B705);
  static const goldDark = Color(0xFFC79300);

  static const textLight = Color(0xFFF3F5F9);
  static const textMuted = Color(0xFF8C9AB4);

  static const green = Color(0xFF2ECC71);
  static const red = Color(0xFFE8534B);
  static const blue = Color(0xFF4AA3F0);
  static const orange = Color(0xFFF08A3C);
  static const purple = Color(0xFFB673E0);

  /// Color de acento tradicional de bingo para cada columna.
  static Color letter(String letter) => switch (letter) {
        'B' => red,
        'I' => orange,
        'N' => green,
        'G' => blue,
        'O' => purple,
        _ => gold,
      };
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.dark,
      surface: AppColors.bgPanel,
      primary: AppColors.gold,
    ),
    scaffoldBackgroundColor: AppColors.bgDark,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.textLight, displayColor: AppColors.textLight),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgDark,
      foregroundColor: AppColors.gold,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgCard,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gold)),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.bgPanel),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.bgCard,
      contentTextStyle: TextStyle(color: AppColors.textLight),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
