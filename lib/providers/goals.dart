import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/goal.dart';
import 'services.dart';

/// 活跃目标列表 Provider。
///
/// 调用 ref.invalidate(activeGoalsProvider) 强制刷新。
final activeGoalsProvider = FutureProvider.autoDispose<List<Goal>>((ref) async {
  return ref.read(goalServiceProvider).getActiveGoals();
});
