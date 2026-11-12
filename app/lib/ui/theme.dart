import 'package:flutter/material.dart';

const brandColor = Color(0xFF0E9F8E);
const brandDark = Color(0xFF0B5D63);

/// The gradient behind the splash, onboarding, sign-in and promo blocks.
const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [brandColor, brandDark],
);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: brandColor, brightness: brightness);
  final isLight = brightness == Brightness.light;
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: scheme,
    scaffoldBackgroundColor: isLight ? const Color(0xFFF4F7F7) : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: isLight ? const Color(0xFFF4F7F7) : scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor(scheme),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Background of cards and assistant bubbles: white in light theme, raised grey in dark.
Color cardColor(ColorScheme scheme) =>
    scheme.brightness == Brightness.light ? Colors.white : scheme.surfaceContainerHigh;

/// Icon of a niche.
IconData categoryIcon(String? category) => switch (category) {
      'dental' => Icons.medical_services_outlined,
      'clinic' => Icons.local_hospital_outlined,
      'barber' => Icons.content_cut,
      'beauty' => Icons.face_retouching_natural,
      'massage' => Icons.spa_outlined,
      'fitness' => Icons.fitness_center,
      'auto' => Icons.car_repair,
      'carwash' => Icons.local_car_wash_outlined,
      'tutor' => Icons.school_outlined,
      'vet' => Icons.pets,
      _ => Icons.apps,
    };

/// Accent colour of a niche, used behind its icon.
Color categoryColor(String? category) => switch (category) {
      'dental' => const Color(0xFF0E9F8E),
      'clinic' => const Color(0xFFE5484D),
      'barber' => const Color(0xFF4F5BD5),
      'beauty' => const Color(0xFFD6409F),
      'massage' => const Color(0xFF8E4EC6),
      'fitness' => const Color(0xFFF76B15),
      'auto' => const Color(0xFF3E63DD),
      'carwash' => const Color(0xFF0090C1),
      'tutor' => const Color(0xFFB7791F),
      'vet' => const Color(0xFF3D9A50),
      _ => brandColor,
    };

/// Colour of a booking status.
Color statusColor(String status, ColorScheme scheme) => switch (status) {
      'completed' => const Color(0xFF2E9E5B),
      'cancelled' => scheme.outline,
      'no_show' => scheme.error,
      _ => scheme.primary,
    };
