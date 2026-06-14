import 'package:flutter/material.dart';
import 'services/goal_service.dart';
import 'services/habit_service.dart';
import 'services/review_service.dart';
import 'pages/onboarding_page.dart';
import 'pages/goal_create_page.dart';
import 'pages/main_page.dart';
import 'pages/habit_create_page.dart';
import 'pages/habit_edit_page.dart';
import 'pages/habit_detail_page.dart';
import 'pages/review_page.dart';

import 'services/frequency_service.dart';

class AtomsApp extends StatelessWidget {
  final GoalService goalService;
  final HabitService habitService;
  final ReviewService reviewService;
  final GlobalKey<MainPageState> mainPageKey;
  final GlobalKey<NavigatorState> navigatorKey;

  const AtomsApp({
    super.key,
    required this.goalService,
    required this.habitService,
    required this.reviewService,
    required this.mainPageKey,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atoms',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1B5E20),
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      initialRoute: '/onboarding',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => MainPage(
                key: mainPageKey,
                goalService: goalService,
                habitService: habitService,
                reviewService: reviewService,
              ),
            );
          case '/onboarding':
            return MaterialPageRoute(
              builder: (_) => OnboardingPage(
                goalService: goalService,
                habitService: habitService,
              ),
            );
          case '/create-goal':
            return MaterialPageRoute(
              builder: (_) => GoalCreatePage(
                goalService: goalService,
                habitService: habitService,
              ),
            );
          case '/create-habit':
            return MaterialPageRoute(
              builder: (_) => HabitCreatePage(
                goalService: goalService,
                habitService: habitService,
                contextGoalId: settings.arguments as int?,
              ),
            );
          case '/edit-habit':
            return MaterialPageRoute(
              builder: (_) => HabitEditPage(
                goalService: goalService,
                habitService: habitService,
                habitId: settings.arguments as int,
              ),
            );
          case '/habit-detail':
            return MaterialPageRoute(
              builder: (_) => HabitDetailPage(
                goalService: goalService,
                habitService: habitService,
                frequencyService: FrequencyService(),
                habitId: settings.arguments as int,
              ),
            );
          case '/review':
            return MaterialPageRoute(
              builder: (_) => ReviewPage(
                goalService: goalService,
                habitService: habitService,
                reviewService: reviewService,
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => MainPage(
                key: mainPageKey,
                goalService: goalService,
                habitService: habitService,
                reviewService: reviewService,
              ),
            );
        }
      },
    );
  }
}
