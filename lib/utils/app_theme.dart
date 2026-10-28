import 'package:flutter/material.dart';

class AppTheme {
  static const Color _seedColor = Color(0xFF0F6E8C);
  static const double _tapTargetHeight = 56;
  static const BorderRadius _cardRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius _inputRadius = BorderRadius.all(
    Radius.circular(12),
  );
  static const BorderRadius _dialogRadius = BorderRadius.all(
    Radius.circular(28),
  );
  static const BorderRadius _fabRadius = BorderRadius.all(Radius.circular(16));

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    return _buildTheme(colorScheme);
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );

    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: isDark
          ? colorScheme.surface
          : colorScheme.surfaceContainerLowest,
      textTheme: Typography.material2021().englishLike
          .apply(
            bodyColor: colorScheme.onSurface,
            displayColor: colorScheme.onSurface,
          )
          .copyWith(
            titleLarge: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            titleMedium: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            titleSmall: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: const TextStyle(fontSize: 16, height: 1.35),
            bodyMedium: const TextStyle(fontSize: 15, height: 1.35),
            bodySmall: const TextStyle(fontSize: 13, height: 1.35),
            labelLarge: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 3.0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: colorScheme.surfaceTint,
        foregroundColor: colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(size: 24, color: colorScheme.onSurfaceVariant),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: _cardRadius,
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: _dialogRadius),
        backgroundColor: colorScheme.surfaceContainerHigh,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 16,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: _cardRadius),
        iconColor: colorScheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(64, _tapTargetHeight),
          shape: const StadiumBorder(),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, _tapTargetHeight),
          shape: const StadiumBorder(),
          side: BorderSide(color: colorScheme.outline),
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, _tapTargetHeight),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      dividerTheme: DividerThemeData(
        thickness: 1,
        color: colorScheme.outlineVariant,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: _fabRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),
    );
  }
}
