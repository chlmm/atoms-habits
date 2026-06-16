import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cli_bridge/cli_bridge.dart';

import 'modules/database.dart';
import 'services/goal_service.dart';
import 'services/habit_service.dart';
import 'services/review_service.dart';
import 'services/todo_service.dart';
import 'services/frequency_service.dart';
import 'providers/services.dart';
import 'modules/cli.dart';
import 'pages/main_page.dart';
import 'app.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  int cliPort = 9999;
  for (final arg in args) {
    if (arg.startsWith('--cli-port=')) {
      cliPort =
          int.tryParse(arg.substring('--cli-port='.length)) ?? 9999;
    }
  }

  final db = AppDatabase();
  await db.init();

  final goalService = GoalService(db);
  final habitService = HabitService(db);
  final reviewService = ReviewService(db);
  final frequencyService = FrequencyService();
  final todoService = TodoService(db, frequencyService);

  // Global keys for CLI access
  final mainPageKey = GlobalKey<MainPageState>();
  final navigatorKey = GlobalKey<NavigatorState>();

  // ── 用 cli_bridge 框架替代旧 CliService ──
  final bridge = CliBridge(port: cliPort);
  setupCliBridge(
    bridge, db, goalService, habitService, reviewService,
    todoService, mainPageKey, navigatorKey,
  );
  await bridge.start();

  runApp(
    ProviderScope(
      overrides: [
        goalServiceProvider.overrideWithValue(goalService),
        habitServiceProvider.overrideWithValue(habitService),
        reviewServiceProvider.overrideWithValue(reviewService),
        todoServiceProvider.overrideWithValue(todoService),
      ],
      child: AtomsApp(
        goalService: goalService,
        habitService: habitService,
        reviewService: reviewService,
        todoService: todoService,
        mainPageKey: mainPageKey,
        navigatorKey: navigatorKey,
      ),
    ),
  );
}
