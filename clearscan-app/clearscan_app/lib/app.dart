import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_text_styles.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/assessment/screens/assessment_screen.dart';
import 'features/enhancement/screens/enhancement_screen.dart';
import 'features/results/screens/results_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'models/assessment_result.dart';
import 'models/enhancement_result.dart';

GoRouter _buildRouter() => GoRouter(
      initialLocation: '/home',
      redirect: (context, state) async {
        final prefs = await SharedPreferences.getInstance();
        final done = prefs.getBool('onboarding_complete') ?? false;
        if (!done && state.uri.path != '/onboarding') {
          return '/onboarding';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (_, __) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/assessment',
          builder: (_, state) {
            final file = state.extra as File;
            return AssessmentScreen(imageFile: file);
          },
        ),
        GoRoute(
          path: '/enhancement',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>;
            return EnhancementScreen(
              imageFile: extra['file'] as File,
              assessmentResult: extra['assessmentResult'] as AssessmentResult,
            );
          },
        ),
        GoRoute(
          path: '/results',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>;
            return ResultsScreen(
              imageFile: extra['file'] as File,
              assessmentResult: extra['assessmentResult'] as AssessmentResult,
              enhancementResult:
                  extra['enhancementResult'] as EnhancementResult,
            );
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
      ],
    );

class ClearScanApp extends StatelessWidget {
  const ClearScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: _AppBody(),
    );
  }
}

class _AppBody extends StatefulWidget {
  @override
  State<_AppBody> createState() => _AppBodyState();
}

class _AppBodyState extends State<_AppBody> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ClearScan',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: AppTextStyles.titleLarge
              .copyWith(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          color: AppColors.surface,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 14),
            textStyle: AppTextStyles.labelLarge
                .copyWith(color: Colors.white),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        dividerTheme: const DividerThemeData(
            color: AppColors.divider, space: 1, thickness: 1),
      ),
    );
  }
}
