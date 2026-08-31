import 'package:flutter/material.dart';

import 'pinori_colours.dart';

class PinoriTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      scaffoldBackgroundColor: PinoriColours.ivoryMist,

      colorScheme: const ColorScheme.light(
        primary: PinoriColours.tomatoJam,
        secondary: PinoriColours.darkCyan,
        surface: PinoriColours.ivoryMist,
        onPrimary: PinoriColours.ivoryMist,
        onSecondary: PinoriColours.ivoryMist,
        onSurface: PinoriColours.richMahogany,
      ),

      // POP-UPS / DIALOGS
      dialogTheme: DialogThemeData(
        backgroundColor: PinoriColours.ivoryMist,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: PinoriColours.richMahogany, width: 4),
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      // BOTTOM SHEETS
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PinoriColours.ivoryMist,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: PinoriColours.richMahogany, width: 4),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
    );
  }
}
