import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// -- Design System: Slate & Clean --
const Color kSlate = Color(0xFF1E293B);
const Color kSlateLight = Color(0xFF334155);
const Color kSlateMuted = Color(0xFF64748B);
const Color kSurface = Color(0xFFF8FAFC);
const Color kSurfaceWhite = Colors.white;

const Color kPrimary = Color(0xFF2563EB); // Blue
const Color kSecondary = Color(0xFF059669); // Green
const Color kAmber = Color(0xFFD97706);
const Color kRed = Color(0xFFDC2626);

const Color primaryColor = kPrimary;
const Color secondaryColor = kSecondary;
const Color tertiaryColor = Color(0xFF7C3AED);
const Color errorColor = kRed;
const Color successColor = kSecondary;
const Color warningColor = kAmber;

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: kPrimary,
    secondary: kSecondary,
    tertiary: tertiaryColor,
    error: kRed,
    surface: kSurfaceWhite,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: kSlate,
  ),
  scaffoldBackgroundColor: kSurface,
  textTheme: GoogleFonts.dmSansTextTheme().copyWith(
    headlineLarge: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: kSlate),
    headlineMedium: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: kSlate),
    titleLarge: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: kSlate),
    titleMedium: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: kSlate),
    bodyLarge: GoogleFonts.dmSans(color: kSlateLight),
    bodyMedium: GoogleFonts.dmSans(color: kSlateLight),
    labelLarge: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
  ),
  appBarTheme: AppBarTheme(
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: GoogleFonts.dmSans(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    backgroundColor: kSlate,
    foregroundColor: Colors.white,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    clipBehavior: Clip.antiAlias,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimary, width: 2),
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: GoogleFonts.dmSans(color: kSlateMuted),
    hintStyle: GoogleFonts.dmSans(color: Colors.grey.shade400),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      backgroundColor: kSlate,
      foregroundColor: Colors.white,
      textStyle: GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: kSlate),
      textStyle: GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      textStyle: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: kSlate,
    foregroundColor: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: kSlate,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    contentTextStyle: GoogleFonts.dmSans(
      color: Colors.white,
      fontSize: 14,
    ),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    titleTextStyle: GoogleFonts.dmSans(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: kSlate,
    ),
  ),
  dividerTheme: DividerThemeData(
    color: Colors.grey.shade200,
    thickness: 1,
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
  ),
  popupMenuTheme: PopupMenuThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 4,
    surfaceTintColor: Colors.transparent,
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: kPrimary,
  ),
);
