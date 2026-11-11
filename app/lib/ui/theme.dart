import 'package:flutter/material.dart';

const brandColor = Color(0xFF0E9F8E);
const brandDark = Color(0xFF0B5D63);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: brandColor, brightness: brightness);
  final isLight = brightness == Brightness.light;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isLight ? const Color(0xFFF4F7F7) : scheme.surface,
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
  );
}

/// Background of cards and assistant bubbles: white in light theme, raised grey in dark.
Color cardColor(ColorScheme scheme) =>
    scheme.brightness == Brightness.light ? Colors.white : scheme.surfaceContainerHigh;

/// Icon for a business category id.
IconData categoryIcon(String? category) => switch (category) {
      'dental' => Icons.medical_services_outlined,
      'barber' => Icons.content_cut,
      'auto' => Icons.directions_car_outlined,
      _ => Icons.apps,
    };
