import 'package:flutter/material.dart';
import 'colors.dart';

abstract class AppTypography {
  static const _base = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static TextStyle get title => _base.copyWith(
    fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3,
  );

  static TextStyle get body => _base.copyWith(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.5,
  );

  static TextStyle get bodySmall => _base.copyWith(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );

  static TextStyle get caption => _base.copyWith(
    fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.2,
  );
}
