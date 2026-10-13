import 'package:flutter/material.dart';

/// Brand color, kept in sync with the web portal's Tailwind `brand-600`.
const Color brandColor = Color(0xFF4F46E5);

/// Light brand tint, matches web `brand-50`.
const Color brandColorLight = Color(0xFFEEF2FF);

/// Convenience Material 3 theme matching the web design language.
ThemeData buildBrandTheme(Brightness brightness) => ThemeData(
      colorSchemeSeed: brandColor,
      useMaterial3: true,
      brightness: brightness,
    );
