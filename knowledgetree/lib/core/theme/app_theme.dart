import 'package:flutter/material.dart';
import 'colors.dart';

abstract class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.textOnPrimary,
          secondary: AppColors.ai,
          onSecondary: AppColors.textOnPrimary,
          tertiary: AppColors.success,
          onTertiary: AppColors.textOnPrimary,
          surface: AppColors.surface,
          onSurface: AppColors.textOnSurface,
          surfaceContainer: AppColors.surfaceCard,
          surfaceContainerHigh: AppColors.surfaceElevated,
          outline: AppColors.border,
          outlineVariant: AppColors.borderStrong,
          error: AppColors.urgent,
          onError: AppColors.textOnPrimary,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        cardColor: AppColors.surfaceCard,
        canvasColor: AppColors.surface,
        dividerColor: AppColors.border,
        shadowColor: Colors.black26,
        cardTheme: CardThemeData(
          color: AppColors.surfaceCard,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          shadowColor: Colors.transparent,
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.urgent, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.urgent, width: 2),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
          floatingLabelStyle: const TextStyle(color: AppColors.primary, fontSize: 12),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceCard,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          titleTextStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: AppColors.surfaceCard,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            side: BorderSide(color: AppColors.border, width: 1),
          ),
          modalBackgroundColor: AppColors.surfaceCard,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surfaceCard,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12);
            }
            return const TextStyle(color: AppColors.textTertiary, fontSize: 12);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primary, size: 24);
            }
            return const IconThemeData(color: AppColors.textTertiary, size: 24);
          }),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.primary, width: 3),
            insets: EdgeInsets.symmetric(horizontal: 16),
          ),
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          dividerColor: Colors.transparent,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceElevated,
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          disabledColor: AppColors.surfaceElevated.withValues(alpha: 0.5),
          labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
          secondaryLabelStyle: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
          side: const BorderSide(color: AppColors.border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(color: AppColors.surface, fontSize: 12, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          preferBelow: true,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.textPrimary,
          contentTextStyle: const TextStyle(color: AppColors.surface, fontSize: 14),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          iconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),
          actionsIconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),
        ),
        listTileTheme: ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tileColor: Colors.transparent,
          selectedTileColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textColor: AppColors.textPrimary,
          iconColor: AppColors.textSecondary,
          titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
          subtitleTextStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
          space: 1,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
          linearTrackColor: AppColors.surfaceElevated,
          circularTrackColor: AppColors.surfaceElevated,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: AppColors.surfaceElevated,
          thumbColor: AppColors.primary,
          overlayColor: AppColors.primary.withValues(alpha: 0.12),
          valueIndicatorColor: AppColors.primary,
          valueIndicatorTextStyle: const TextStyle(color: AppColors.textOnPrimary, fontSize: 12),
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary;
            return AppColors.textTertiary;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary.withValues(alpha: 0.4);
            return AppColors.surfaceElevated;
          }),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary;
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(AppColors.textOnPrimary),
          side: const BorderSide(color: AppColors.borderStrong, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary;
            return AppColors.textTertiary;
          }),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 4,
          focusElevation: 6,
          hoverElevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        extensions: const <ThemeExtension<dynamic>>[],
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: DarkColors.primary,
          onPrimary: AppColors.textOnPrimary,
          secondary: DarkColors.ai,
          onSecondary: AppColors.textOnPrimary,
          tertiary: AppColors.successLight,
          onTertiary: AppColors.textOnPrimary,
          surface: DarkColors.surface,
          onSurface: AppColors.textPrimary,
          surfaceContainer: DarkColors.surfaceCard,
          surfaceContainerHigh: DarkColors.surfaceElevated,
          outline: DarkColors.border,
          outlineVariant: DarkColors.border,
          error: AppColors.urgentLight,
          onError: AppColors.textOnPrimary,
        ),
        scaffoldBackgroundColor: DarkColors.surface,
        cardColor: DarkColors.surfaceCard,
        canvasColor: DarkColors.surface,
        dividerColor: DarkColors.border,
        shadowColor: Colors.black54,
        cardTheme: CardThemeData(
          color: DarkColors.surfaceCard,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: DarkColors.border, width: 1),
          ),
          shadowColor: Colors.transparent,
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: DarkColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: DarkColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: DarkColors.primary,
            side: const BorderSide(color: DarkColors.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: DarkColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: DarkColors.surfaceCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DarkColors.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DarkColors.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DarkColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.urgentLight, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.urgentLight, width: 2),
          ),
          labelStyle: const TextStyle(color: DarkColors.textSecondary, fontSize: 14),
          hintStyle: const TextStyle(color: DarkColors.textTertiary, fontSize: 14),
          floatingLabelStyle: const TextStyle(color: DarkColors.primary, fontSize: 12),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: DarkColors.surfaceCard,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: DarkColors.border, width: 1),
          ),
          titleTextStyle: const TextStyle(
            color: DarkColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: const TextStyle(
            color: DarkColors.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: DarkColors.surfaceCard,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            side: BorderSide(color: DarkColors.border, width: 1),
          ),
          modalBackgroundColor: DarkColors.surfaceCard,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: DarkColors.surfaceCard,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: DarkColors.primary.withValues(alpha: 0.15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: DarkColors.primary, fontWeight: FontWeight.w600, fontSize: 12);
            }
            return const TextStyle(color: DarkColors.textTertiary, fontSize: 12);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: DarkColors.primary, size: 24);
            }
            return const IconThemeData(color: DarkColors.textTertiary, size: 24);
          }),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: DarkColors.primary,
          unselectedLabelColor: DarkColors.textTertiary,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: DarkColors.primary, width: 3),
            insets: EdgeInsets.symmetric(horizontal: 16),
          ),
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          dividerColor: Colors.transparent,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: DarkColors.surfaceElevated,
          selectedColor: DarkColors.primary.withValues(alpha: 0.2),
          disabledColor: DarkColors.surfaceElevated.withValues(alpha: 0.5),
          labelStyle: const TextStyle(color: DarkColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
          secondaryLabelStyle: const TextStyle(color: DarkColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
          side: const BorderSide(color: DarkColors.border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: DarkColors.textPrimary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(color: DarkColors.surface, fontSize: 12, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          preferBelow: true,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: DarkColors.textPrimary,
          contentTextStyle: const TextStyle(color: DarkColors.surface, fontSize: 14),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: DarkColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          iconTheme: IconThemeData(color: DarkColors.textPrimary, size: 24),
          actionsIconTheme: IconThemeData(color: DarkColors.textPrimary, size: 24),
        ),
        listTileTheme: ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tileColor: Colors.transparent,
          selectedTileColor: DarkColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textColor: DarkColors.textPrimary,
          iconColor: DarkColors.textSecondary,
          titleTextStyle: TextStyle(color: DarkColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
          subtitleTextStyle: TextStyle(color: DarkColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        dividerTheme: const DividerThemeData(
          color: DarkColors.border,
          thickness: 1,
          space: 1,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: DarkColors.primary,
          linearTrackColor: DarkColors.surfaceElevated,
          circularTrackColor: DarkColors.surfaceElevated,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: DarkColors.primary,
          inactiveTrackColor: DarkColors.surfaceElevated,
          thumbColor: DarkColors.primary,
          overlayColor: DarkColors.primary.withValues(alpha: 0.15),
          valueIndicatorColor: DarkColors.primary,
          valueIndicatorTextStyle: const TextStyle(color: AppColors.textOnPrimary, fontSize: 12),
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return DarkColors.primary;
            return DarkColors.textTertiary;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return DarkColors.primary.withValues(alpha: 0.4);
            return DarkColors.surfaceElevated;
          }),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return DarkColors.primary;
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(AppColors.textOnPrimary),
          side: const BorderSide(color: DarkColors.border, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return DarkColors.primary;
            return DarkColors.textTertiary;
          }),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: DarkColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 4,
          focusElevation: 6,
          hoverElevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
      );
}