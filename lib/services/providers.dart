import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart';
import 'goal_service.dart';
import 'habit_service.dart';
import 'review_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final goalServiceProvider = Provider<GoalService>((ref) {
  return GoalService(ref.watch(databaseProvider));
});

final habitServiceProvider = Provider<HabitService>((ref) {
  return HabitService(ref.watch(databaseProvider));
});

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService(ref.watch(databaseProvider));
});
