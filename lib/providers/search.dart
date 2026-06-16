import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/goal_service.dart';
import '../models/goal.dart';
import '../models/milestone.dart';
import 'services.dart';

/// 搜索结果类型
enum SearchResultType { goal, milestone }

/// 单条搜索结果
class SearchResult {
  final SearchResultType type;
  final int? id;
  final String title;
  final String? subtitle;

  const SearchResult({
    required this.type,
    this.id,
    required this.title,
    this.subtitle,
  });
}

/// 搜索模块状态
// @immutable — using const constructor instead
class SearchState {
  final List<Goal> allGoals;
  final List<Milestone> allMilestones;
  final Map<int, String> goalNames;
  final bool dataLoaded;
  final String query;
  final List<SearchResult> results;
  final List<String> history;

  const SearchState({
    this.allGoals = const [],
    this.allMilestones = const [],
    this.goalNames = const {},
    this.dataLoaded = false,
    this.query = '',
    this.results = const [],
    this.history = const [],
  });

  SearchState copyWith({
    List<Goal>? allGoals,
    List<Milestone>? allMilestones,
    Map<int, String>? goalNames,
    bool? dataLoaded,
    String? query,
    List<SearchResult>? results,
    List<String>? history,
  }) {
    return SearchState(
      allGoals: allGoals ?? this.allGoals,
      allMilestones: allMilestones ?? this.allMilestones,
      goalNames: goalNames ?? this.goalNames,
      dataLoaded: dataLoaded ?? this.dataLoaded,
      query: query ?? this.query,
      results: results ?? this.results,
      history: history ?? this.history,
    );
  }
}

/// 搜索 Notifier — 封装全部搜索逻辑
class SearchNotifier extends StateNotifier<SearchState> {
  final GoalService _goalService;
  static const _maxHistory = 12;

  SearchNotifier(this._goalService) : super(const SearchState());

  /// 加载全量搜索数据
  Future<void> loadData() async {
    if (state.dataLoaded) return;
    try {
      final goals = await _goalService.getAllGoals();
      final milestones = <Milestone>[];
      final goalNames = <int, String>{};
      for (final g in goals) {
        if (g.id != null) {
          goalNames[g.id!] = g.name;
          final ms = await _goalService.getMilestonesByGoal(g.id!);
          milestones.addAll(ms);
        }
      }
      state = state.copyWith(
        allGoals: goals,
        allMilestones: milestones,
        goalNames: goalNames,
        dataLoaded: true,
      );
      _performSearch();
    } catch (_) {
      state = state.copyWith(dataLoaded: true);
    }
  }

  /// 设置查询文本并触发搜索
  void setQuery(String q) {
    state = state.copyWith(query: q);
    if (q.trim().isEmpty) {
      state = state.copyWith(results: []);
      return;
    }
    _performSearch();
  }

  /// 重置搜索状态（关闭搜索时调用）
  void reset() {
    state = state.copyWith(query: '', results: []);
  }

  void _performSearch() {
    final lowerQ = state.query.toLowerCase().trim();
    if (lowerQ.isEmpty) return;

    final results = <SearchResult>[];

    for (final g in state.allGoals) {
      if (g.name.toLowerCase().contains(lowerQ)) {
        results.add(SearchResult(
          type: SearchResultType.goal,
          id: g.id,
          title: g.name,
          subtitle: _goalStatusLabel(g.status),
        ));
      }
    }

    for (final m in state.allMilestones) {
      if (m.name.toLowerCase().contains(lowerQ)) {
        final parentName = state.goalNames[m.goalId] ?? '';
        results.add(SearchResult(
          type: SearchResultType.milestone,
          id: m.id,
          title: m.name,
          subtitle: parentName.isNotEmpty
              ? '$parentName · ${_milestoneStatusLabel(m.status)}'
              : _milestoneStatusLabel(m.status),
        ));
      }
    }

    state = state.copyWith(results: results);
  }

  void addToHistory(String q) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    final updated = [
      trimmed,
      ...state.history.where((e) => e != trimmed),
    ];
    if (updated.length > _maxHistory) {
      updated.removeRange(_maxHistory, updated.length);
    }
    state = state.copyWith(history: updated);
  }

  void removeFromHistory(String item) {
    state = state.copyWith(
      history: state.history.where((e) => e != item).toList(),
    );
  }

  void clearHistory() {
    state = state.copyWith(history: []);
  }

  static String _goalStatusLabel(String status) {
    switch (status) {
      case 'active':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'archived':
        return '已归档';
      default:
        return status;
    }
  }

  static String _milestoneStatusLabel(String status) {
    switch (status) {
      case 'active':
        return '进行中';
      case 'completed':
        return '已完成';
      default:
        return '等待中';
    }
  }
}

/// 搜索 Provider
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.read(goalServiceProvider));
});
