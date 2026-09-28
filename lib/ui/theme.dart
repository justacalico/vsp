import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// VSP's visual language: near-black surfaces, one calm blue accent,
/// SF-style type scale. Depth comes from hairline borders and subtle
/// fills, not gradients or shadows.
class VspTheme {
  VspTheme._();

  static const accent = Color(0xFF0A84FF);
  static const accentDark = Color(0xFF007AFF);
  static const ok = Color(0xFF30D158);
  static const warn = Color(0xFFFF9F0A);
  static const danger = Color(0xFFFF453A);

  static const _bgDark = Color(0xFF0B0D11);
  static const _surfaceDark = Color(0xFF15181E);
  static const _surface2Dark = Color(0xFF1C2028);
  static const _hairlineDark = Color(0xFF2A2F38);

  static const _bgLight = Color(0xFFF5F5F7);
  static const _surfaceLight = Color(0xFFFFFFFF);
  static const _surface2Light = Color(0xFFEFEFF2);
  static const _hairlineLight = Color(0xFFD9D9DE);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true).copyWith(
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter'),
    );
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bgDark,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        secondary: accent,
        surface: _surfaceDark,
        onSurface: Color(0xFFF2F2F5),
        surfaceContainerHighest: _surface2Dark,
        outline: _hairlineDark,
        error: danger,
      ),
      cardTheme: CardThemeData(
        color: _surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _hairlineDark, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _hairlineDark,
        thickness: 0.5,
        space: 0.5,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: _hairlineDark),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface2Dark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _hairlineDark, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.2),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _hairlineDark, width: 0.5),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true).copyWith(
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Inter'),
    );
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: _bgLight,
      colorScheme: const ColorScheme.light(
        primary: accentDark,
        onPrimary: Colors.white,
        secondary: accentDark,
        surface: _surfaceLight,
        onSurface: Color(0xFF1C1C1E),
        surfaceContainerHighest: _surface2Light,
        outline: _hairlineLight,
        error: Color(0xFFD70015),
      ),
      cardTheme: CardThemeData(
        color: _surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _hairlineLight, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _hairlineLight,
        thickness: 0.5,
        space: 0.5,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: _hairlineLight),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface2Light,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _hairlineLight, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accentDark, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _hairlineLight, width: 0.5),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
