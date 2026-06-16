import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../services/review_service.dart';
import '../services/todo_service.dart';
import '../services/frequency_service.dart';

// 使用 Provider<T> 而非 StateProvider，因为这些 Service 实例在 main() 中创建
// 通过 override 注入，ProviderScope 全局可用

final goalServiceProvider = Provider<GoalService>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

final habitServiceProvider = Provider<HabitService>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

final reviewServiceProvider = Provider<ReviewService>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

final todoServiceProvider = Provider<TodoService>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

final frequencyServiceProvider = Provider<FrequencyService>((ref) {
  return FrequencyService();
});
