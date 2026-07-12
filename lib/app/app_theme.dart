import 'package:flutter/material.dart';
import 'package:calcx/core/services/theme_service.dart';

class AppTheme {
  static ThemeData dark() => themeForSettings(ThemeSettings(themeName: 'cyberpunk'));

  static ThemeData themeForName(String name) => themeForSettings(ThemeSettings(themeName: name));

  static ThemeData themeForSettings(ThemeSettings settings) {
    final name = settings.themeName;
    Brightness brightness = Brightness.dark;

    Color primary = const Color(0xFF00DBE9); // cyan
    Color secondary = const Color(0xFFB600F8); // magenta
    Color tertiary = const Color(0xFFD1BCFF); // violet
    Color background = const Color(0xFF050505);
    Color surface = const Color(0xFF131313);

    if (name == 'light') {
      brightness = Brightness.light;
      primary = const Color(0xFF6750A4); // Material Indigo
      secondary = const Color(0xFF625B71);
      tertiary = const Color(0xFF7D5260);
      background = const Color(0xFFF6F5FA);
      surface = const Color(0xFFFFFFFF);
    } else if (name == 'amoled') {
      primary = const Color(0xFF00DBE9);
      secondary = const Color(0xFFB600F8);
      tertiary = const Color(0xFFD1BCFF);
      background = const Color(0xFF000000); // Pure Black
      surface = const Color(0xFF0A0A0A);
    } else if (name == 'emerald') {
      primary = const Color(0xFF00E676);
      secondary = const Color(0xFF00B0FF);
      tertiary = const Color(0xFFB9F6CA);
      background = const Color(0xFF030805);
      surface = const Color(0xFF0F1712);
    } else if (name == 'sunset') {
      primary = const Color(0xFFFF5722);
      secondary = const Color(0xFFFF007F);
      tertiary = const Color(0xFFFFD54F);
      background = const Color(0xFF0A0503);
      surface = const Color(0xFF17100D);
    } else if (name == 'crimson') {
      primary = const Color(0xFFFF1744);
      secondary = const Color(0xFFFFD700);
      tertiary = const Color(0xFFFF8A80);
      background = const Color(0xFF080202);
      surface = const Color(0xFF160D0E);
    } else if ((name == 'material_you' || name == 'gallery') && settings.seedColorValue != null) {
      primary = Color(settings.seedColorValue!);
      secondary = primary.withBlue(100).withRed(50);
      tertiary = primary.withGreen(150);
    }

    final ColorScheme scheme = (settings.seedColorValue != null && (name == 'material_you' || name == 'gallery'))
        ? ColorScheme.fromSeed(
            seedColor: Color(settings.seedColorValue!),
            brightness: brightness,
            primary: Color(settings.seedColorValue!),
          )
        : ColorScheme.fromSeed(
            seedColor: primary,
            brightness: brightness,
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            surface: surface,
            error: const Color(0xFFFF5D73),
          );

    final isLight = brightness == Brightness.light;
    final baseTextTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    ).textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Geist',
      textTheme: _textTheme(baseTextTheme, isLight),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: isLight ? Colors.black87 : Colors.white),
        titleTextStyle: TextStyle(
          color: isLight ? Colors.black87 : Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? const Color(0xFFF0F0F5) : const Color(0xFF0E0E0E).withValues(alpha: 0.78),
        indicatorColor: primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontWeight: FontWeight.w700, color: isLight ? Colors.black87 : Colors.white),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isLight ? Colors.black12 : Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isLight ? Colors.black12 : Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, bool isLight) {
    final Color textColor = isLight ? Colors.black87 : Colors.white;
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: 'Sora',
        letterSpacing: 0,
        color: textColor,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: 'Sora',
        letterSpacing: 0,
        color: textColor,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: 'Sora',
        letterSpacing: 0,
        color: textColor,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: 'Sora',
        letterSpacing: 0,
        color: textColor,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: 'Sora',
        letterSpacing: 0,
        color: textColor,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontFamily: 'Sora',
        letterSpacing: 0,
        color: textColor,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: 'Geist',
        letterSpacing: 0,
        color: textColor,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: 'Geist',
        letterSpacing: 0,
        color: textColor,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: 'Geist',
        letterSpacing: 0,
        color: textColor,
      ),
    );
  }
}
