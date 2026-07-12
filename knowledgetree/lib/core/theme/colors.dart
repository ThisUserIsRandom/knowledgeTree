import 'package:flutter/material.dart';

abstract class AppColors {
  // ============ LIGHT THEME - PRIMARY ============
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryLight = Color(0xFF6366F1); // Indigo 500
  static const Color primaryLighter = Color(0xFF818CF8); // Indigo 400
  static const Color primaryDark = Color(0xFF4338CA); // Indigo 700
  static const Color primaryContainer = Color(0xFFEEF2FF); // Indigo 50
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF312E81); // Indigo 900

  // ============ LIGHT THEME - SECONDARY (AI) ============
  static const Color ai = Color(0xFF06B6D4); // Cyan 500
  static const Color aiLight = Color(0xFF22D3EE); // Cyan 400
  static const Color aiDark = Color(0xFF0891B2); // Cyan 600
  static const Color aiContainer = Color(0xFFECFEFF); // Cyan 50
  static const Color onAi = Color(0xFFFFFFFF);
  static const Color onAiContainer = Color(0xFF164E63); // Cyan 900

  // ============ LIGHT THEME - SEMANTIC ============
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successLight = Color(0xFF34D399); // Emerald 400
  static const Color successDark = Color(0xFF059669); // Emerald 600
  static const Color successContainer = Color(0xFFECFDF5); // Emerald 50
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color onSuccessContainer = Color(0xFF064E3B); // Emerald 900

  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningLight = Color(0xFFFBBF24); // Amber 400
  static const Color warningDark = Color(0xFFD97706); // Amber 600
  static const Color warningContainer = Color(0xFFFFFBEB); // Amber 50
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color onWarningContainer = Color(0xFF78350F); // Amber 900

  static const Color urgent = Color(0xFFEF4444); // Red 500
  static const Color urgentLight = Color(0xFFF87171); // Red 400
  static const Color urgentDark = Color(0xFFDC2626); // Red 600
  static const Color urgentContainer = Color(0xFFFEF2F2); // Red 50
  static const Color onUrgent = Color(0xFFFFFFFF);
  static const Color onUrgentContainer = Color(0xFF7F1D1D); // Red 900

  // ============ LIGHT THEME - SURFACES ============
  static const Color surface = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceCard = Color(0xFFFFFFFF); // White
  static const Color surfaceElevated = Color(0xFFFFFFFF); // White
  static const Color surfaceHover = Color(0xFFF1F5F9); // Slate 100
  static const Color surfacePressed = Color(0xFFE2E8F0); // Slate 200

  // ============ LIGHT THEME - TEXT ============
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF334155); // Slate 700
  static const Color textTertiary = Color(0xFF64748B); // Slate 500
  static const Color textQuaternary = Color(0xFF94A3B8); // Slate 400
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSurface = Color(0xFF0F172A);
  static const Color textOnSurfaceVariant = Color(0xFF475569); // Slate 600

  // ============ LIGHT THEME - BORDERS ============
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderStrong = Color(0xFFCBD5E1); // Slate 300
  static const Color borderFocus = Color(0xFF4F46E5); // Primary
  static const Color borderError = Color(0xFFEF4444); // Urgent

  // ============ LIGHT THEME - SHADOWS ============
  static const Color shadow = Color(0x1A0F172A); // 10% Slate 900
  static const Color shadowStrong = Color(0x330F172A); // 20% Slate 900

  // ============ LIGHT THEME - OVERLAY ============
  static const Color overlay = Color(0x800F172A); // 50% Slate 900
  static const Color scrim = Color(0x99000000); // 60% Black

  // ============ LIGHT THEME - SPECIFIC COMPONENT COLORS ============
  static const Color searchBg = Color(0xFFFFFFFF);
  static const Color searchBorder = Color(0xFFE2E8F0);
  static const Color searchFocusBorder = Color(0xFF4F46E5);
  static const Color searchPlaceholder = Color(0xFF94A3B8);

  static const Color chatUserBubble = Color(0xFF4F46E5);
  static const Color chatUserText = Color(0xFFFFFFFF);
  static const Color chatAiBubble = Color(0xFFF1F5F9);
  static const Color chatAiText = Color(0xFF1E293B);
  static const Color chatSystemBubble = Color(0xFFECFEFF);
  static const Color chatSystemText = Color(0xFF164E63);

  static const Color nodeCardBg = Color(0xFFFFFFFF);
  static const Color nodeCardBorder = Color(0xFFE2E8F0);
  static const Color nodeCardHover = Color(0xFFF8FAFC);
  static const Color nodeCardShadow = Color(0x1A0F172A);
  static const Color nodeEdgeColor = Color(0xFFCBD5E1);

  static const Color treeBg = Color(0xFFF8FAFC);

  static const Color divider = Color(0xFFE2E8F0);

  static const Color fabBg = Color(0xFF4F46E5);
  static const Color fabText = Color(0xFFFFFFFF);

  static const Color badgeBg = Color(0xFFEEF2FF);
  static const Color badgeText = Color(0xFF312E81);

  static const Color tooltipBg = Color(0xFF1E293B);
  static const Color tooltipText = Color(0xFFF8FAFC);

  static const Color snackbarBg = Color(0xFF1E293B);
  static const Color snackbarText = Color(0xFFF8FAFC);

  static const Color dialogBg = Color(0xFFFFFFFF);
  static const Color dialogBorder = Color(0xFFE2E8F0);

  static const Color bottomSheetBg = Color(0xFFFFFFFF);
  static const Color bottomSheetHandle = Color(0xFFCBD5E1);

  // ============ GRADIENTS ============
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient aiGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============ SHADOWS ============
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x1A0F172A),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x1E0F172A),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 40,
      offset: Offset(0, 12),
    ),
  ];

  // ============ DARK THEME COLORS ============
  static const Color primaryDarkTheme = Color(0xFF818CF8); // Indigo 400
  static const Color onPrimaryDarkTheme = Color(0xFF1E1B4B); // Indigo 950
  static const Color primaryContainerDarkTheme = Color(0xFF312E81); // Indigo 900

  static const Color aiDarkTheme = Color(0xFF22D3EE); // Cyan 400
  static const Color onAiDarkTheme = Color(0xFF164E63); // Cyan 900

  static const Color surfaceDarkTheme = Color(0xFF0F172A); // Slate 900
  static const Color surfaceCardDarkTheme = Color(0xFF1E293B); // Slate 800
  static const Color surfaceElevatedDarkTheme = Color(0xFF334155); // Slate 700
  static const Color surfaceHoverDarkTheme = Color(0xFF334155); // Slate 700
  static const Color surfacePressedDarkTheme = Color(0xFF475569); // Slate 600

  static const Color textPrimaryDarkTheme = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDarkTheme = Color(0xFFE2E8F0); // Slate 200
  static const Color textTertiaryDarkTheme = Color(0xFF94A3B8); // Slate 400
  static const Color textQuaternaryDarkTheme = Color(0xFF64748B); // Slate 500

  static const Color borderDarkTheme = Color(0xFF334155); // Slate 700
  static const Color borderStrongDarkTheme = Color(0xFF475569); // Slate 600

  static const Color shadowDarkTheme = Color(0x4D000000); // 30% Black
  static const Color shadowStrongDarkTheme = Color(0x66000000); // 40% Black

  static const Color chatUserBubbleDarkTheme = Color(0xFF818CF8);
  static const Color chatAiBubbleDarkTheme = Color(0xFF334155);
  static const Color chatAiTextDarkTheme = Color(0xFFF1F5F9);
  static const Color chatSystemBubbleDarkTheme = Color(0xFF1E3A5F);
  static const Color chatSystemTextDarkTheme = Color(0xFFA5F3FC);

  static const Color nodeCardBgDarkTheme = Color(0xFF1E293B);
  static const Color nodeCardBorderDarkTheme = Color(0xFF334155);
  static const Color nodeEdgeColorDarkTheme = Color(0xFF475569);

  static const Color treeBgDarkTheme = Color(0xFF0F172A);
  static const Color dividerDarkTheme = Color(0xFF334155);
}

// ============ DARK THEME CONSTANTS ============
abstract class DarkColors {
  static const Color primary = AppColors.primaryDarkTheme;
  static const Color onPrimary = AppColors.onPrimaryDarkTheme;
  static const Color primaryContainer = AppColors.primaryContainerDarkTheme;
  static const Color onPrimaryContainer = AppColors.onPrimaryDarkTheme;

  static const Color ai = AppColors.aiDarkTheme;
  static const Color onAi = AppColors.onAiDarkTheme;

  static const Color surface = AppColors.surfaceDarkTheme;
  static const Color surfaceCard = AppColors.surfaceCardDarkTheme;
  static const Color surfaceElevated = AppColors.surfaceElevatedDarkTheme;
  static const Color surfaceHover = AppColors.surfaceHoverDarkTheme;
  static const Color surfacePressed = AppColors.surfacePressedDarkTheme;

  static const Color textPrimary = AppColors.textPrimaryDarkTheme;
  static const Color textSecondary = AppColors.textSecondaryDarkTheme;
  static const Color textTertiary = AppColors.textTertiaryDarkTheme;
  static const Color textQuaternary = AppColors.textQuaternaryDarkTheme;

  static const Color border = AppColors.borderDarkTheme;
  static const Color borderStrong = AppColors.borderStrongDarkTheme;
  static const Color borderFocus = AppColors.primaryDarkTheme;

  static const Color shadow = AppColors.shadowDarkTheme;
  static const Color shadowStrong = AppColors.shadowStrongDarkTheme;

  static const Color chatUserBubble = AppColors.chatUserBubbleDarkTheme;
  static const Color chatAiBubble = AppColors.chatAiBubbleDarkTheme;
  static const Color chatAiText = AppColors.chatAiTextDarkTheme;
  static const Color chatSystemBubble = AppColors.chatSystemBubbleDarkTheme;
  static const Color chatSystemText = AppColors.chatSystemTextDarkTheme;

  static const Color nodeCardBg = AppColors.nodeCardBgDarkTheme;
  static const Color nodeCardBorder = AppColors.nodeCardBorderDarkTheme;
  static const Color nodeEdgeColor = AppColors.nodeEdgeColorDarkTheme;

  static const Color treeBg = AppColors.treeBgDarkTheme;
  static const Color divider = AppColors.dividerDarkTheme;
}