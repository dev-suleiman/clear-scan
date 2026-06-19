import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract class AppTextStyles {
  static TextStyle get displayLarge => GoogleFonts.dmSans(
        fontSize: 28, fontWeight: FontWeight.w700,
        color: AppColors.textPrimary, height: 1.5,
      );
  static TextStyle get displayMedium => GoogleFonts.dmSans(
        fontSize: 22, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary, height: 1.5,
      );
  static TextStyle get titleLarge => GoogleFonts.dmSans(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary, height: 1.5,
      );
  static TextStyle get titleMedium => GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w500,
        color: AppColors.textPrimary, height: 1.5,
      );
  static TextStyle get bodyLarge => GoogleFonts.dmSans(
        fontSize: 15, fontWeight: FontWeight.w400,
        color: AppColors.textPrimary, height: 1.5,
      );
  static TextStyle get bodyMedium => GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: AppColors.textSecondary, height: 1.5,
      );
  static TextStyle get labelLarge => GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: AppColors.primary, height: 1.5,
      );
  static TextStyle get labelMedium => GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: AppColors.textSecondary, height: 1.5,
      );
  static TextStyle get caption => GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w400,
        color: AppColors.textSecondary, height: 1.5,
      );
}
