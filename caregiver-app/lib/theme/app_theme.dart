import 'package:flutter/material.dart';

class AppColors {
  static const Color brand = Color(0xFF26A69A);
  static const Color brandDark = Color(0xFF00796B);
  static const Color background = Color(0xFFFFF8F0);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF607D8B);

  static const Color statusGreen = Color(0xFF2E7D32);
  static const Color statusGreenSoft = Color(0xFFE8F5E9);
  static const Color statusAmber = Color(0xFFF9A825);
  static const Color statusAmberSoft = Color(0xFFFFF8E1);
  static const Color statusRed = Color(0xFFD32F2F);
  static const Color statusRedSoft = Color(0xFFFFEBEE);
}

enum AlertLevel { info, concern, urgent, emergency }

extension AlertLevelX on AlertLevel {
  String get label {
    switch (this) {
      case AlertLevel.info:
        return 'OK';
      case AlertLevel.concern:
        return 'Concern';
      case AlertLevel.urgent:
        return 'Urgent';
      case AlertLevel.emergency:
        return 'Emergency';
    }
  }

  Color get color {
    switch (this) {
      case AlertLevel.info:
        return AppColors.statusGreen;
      case AlertLevel.concern:
        return AppColors.statusAmber;
      case AlertLevel.urgent:
      case AlertLevel.emergency:
        return AppColors.statusRed;
    }
  }

  Color get soft {
    switch (this) {
      case AlertLevel.info:
        return AppColors.statusGreenSoft;
      case AlertLevel.concern:
        return AppColors.statusAmberSoft;
      case AlertLevel.urgent:
      case AlertLevel.emergency:
        return AppColors.statusRedSoft;
    }
  }

  IconData get icon {
    switch (this) {
      case AlertLevel.info:
        return Icons.check_circle_rounded;
      case AlertLevel.concern:
        return Icons.error_outline_rounded;
      case AlertLevel.urgent:
        return Icons.warning_amber_rounded;
      case AlertLevel.emergency:
        return Icons.emergency_rounded;
    }
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      surface: AppColors.surface,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.brandDark,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.brandDark,
    ),
  );
}
