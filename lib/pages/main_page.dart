import 'package:flutter/material.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../services/review_service.dart';
import '../services/todo_service.dart';
import '../services/frequency_service.dart';
import '../models/goal.dart';
import '../models/milestone.dart';
import '../components/heatmap.dart';
import '../components/stats_row.dart';
import '../components/day_detail_sheet.dart';
import 'habit_face_page.dart';
import 'goal_face_page.dart';
import 'todo_face_page.dart';

/// R3: 移动端优先主框架。
///
/// 左上角 ☰ 汉堡菜单 → Drawer 抽屉（目标/习惯/设置）
/// 底部中央大 ➕ 按钮（添加习惯或目标）
/// 搜索：全屏内联模式（MemoFlow Android 风格）
class MainPage extends StatefulWidget {
  final GoalService goalService;
  final HabitService habitService;
  final ReviewService reviewService;
  final TodoService todoService;

  const MainPage({
    super.key,
    required this.goalService,
    required this.habitService,
    required this.reviewService,
    required this.todoService,
  });

  @override
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  final FrequencyService _frequencyService = FrequencyService();

  // ── Navigation state ──
  int _selectedIndex = 1; // 0=goal, 1=habit, 2=todo (default to habit face)
  int? _activeGoalId;
  int _habitFaceRefreshKey = 0;
  int _todoFaceRefreshKey = 0;
  List<Goal> _goals = [];
  String _sortBy = 'created_desc';

  // ── Drawer stats / heatmap data (loaded from services) ──
  int _habitCount = 0;
  int _goalCount = 0;
  int _activeDays = 0;
  Map<String, int> _dailyCounts = {};
  bool _drawerDataLoaded = false;

  // ── Search state (full-screen inline, MemoFlow Android style) ──
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<Goal> _allGoals = [];
  List<Milestone> _allMilestones = [];
  Map<int, String> _goalNames = {}; // goalId -> goal name
  List<_SearchResult> _searchResults = [];
  bool _searchDataLoaded = false;

  // ── Search history (in-memory, max 12 items) ──
  static const _maxHistoryItems = 12;
  List<String> _searchHistory = [];

  // Expose state for CLI
  int? get activeGoalId => _activeGoalId;
  String get currentFace => _selectedIndex == 0 ? 'goal' : _selectedIndex == 1 ? 'habit' : 'todo';
  String get sortBy => _sortBy;

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadDrawerData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // DATA
  // ═══════════════════════════════════════════════════════════

  Future<void> _navigateAndRefresh(String route, {Object? arguments}) async {
    await Navigator.pushNamed(context, route, arguments: arguments);
    _loadGoals();
    _loadDrawerData();
    setState(() {
      _habitFaceRefreshKey++;
      _todoFaceRefreshKey++;
    });
  }

  Future<void> _loadGoals() async {
    final goals = await widget.goalService.getActiveGoals();
    if (!mounted) return;
    setState(() {
      _goals = goals;
      if (_activeGoalId == null && goals.isNotEmpty) {
        _activeGoalId = goals.first.id;
      } else if (_activeGoalId != null &&
          !goals.any((g) => g.id == _activeGoalId)) {
        _activeGoalId = goals.isNotEmpty ? goals.first.id : null;
      }
    });
  }

  /// 加载 Drawer 所需的真实统计数据
  Future<void> _loadDrawerData() async {
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      // 热力图覆盖 ~18周 ≈ 126 天前
      final startDate = now.subtract(const Duration(days: 130));
      final startStr =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

      // 并行加载三个数据源
      final results = await Future.wait([
        widget.habitService.getActiveHabitCount(),
        widget.goalService.getAllGoals(), // for goal count
        widget.habitService.getDailyCheckinCounts(
            startDate: startStr, endDate: todayStr),
        widget.habitService.getActiveDaysCount(
            startDate: startStr, endDate: todayStr),
      ]);

      if (!mounted) return;
      setState(() {
        _habitCount = results[0] as int;
        _goalCount = (results[1] as List).length;
        _dailyCounts = results[2] as Map<String, int>;
        _activeDays = results[3] as int;
        _drawerDataLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _drawerDataLoaded = true);
    }
  }

  Future<void> _loadSearchData() async {
    if (_searchDataLoaded) return;
    try {
      final goals = await widget.goalService.getAllGoals();
      final milestones = <Milestone>[];
      final goalNames = <int, String>{};
      for (final g in goals) {
        if (g.id != null) {
          goalNames[g.id!] = g.name;
          final ms = await widget.goalService.getMilestonesByGoal(g.id!);
          milestones.addAll(ms);
        }
      }
      if (!mounted) return;
      setState(() {
        _allGoals = goals;
        _allMilestones = milestones;
        _goalNames = goalNames;
        _searchDataLoaded = true;
      });
      _performSearch();
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchDataLoaded = true);
    }
  }

  void _switchGoal(int goalId) {
    setState(() => _activeGoalId = goalId);
  }

  // ── Search methods ──

  void _openSearch() {
    setState(() {
      _searching = true;
      _searchQuery = '';
      _searchResults = [];
    });
    _searchController.clear();
    _loadSearchData();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _searchQuery = '';
      _searchResults = [];
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text);
    _performSearch();
  }

  void _performSearch() {
    if (_searchQuery.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final lowerQ = _searchQuery.toLowerCase().trim();
    final results = <_SearchResult>[];

    for (final g in _allGoals) {
      if (g.name.toLowerCase().contains(lowerQ)) {
        results.add(_SearchResult(
          type: _ResultType.goal,
          id: g.id,
          title: g.name,
          subtitle: _goalStatusLabel(g.status),
        ));
      }
    }

    for (final m in _allMilestones) {
      if (m.name.toLowerCase().contains(lowerQ)) {
        final parentName = _goalNames[m.goalId] ?? '';
        results.add(_SearchResult(
          type: _ResultType.milestone,
          id: m.id,
          title: m.name,
          subtitle: parentName.isNotEmpty
              ? '$parentName · ${_milestoneStatusLabel(m.status)}'
              : _milestoneStatusLabel(m.status),
        ));
      }
    }

    setState(() => _searchResults = results);
  }

  void _addToHistory(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _searchHistory = [trimmed, ..._searchHistory.where((e) => e != trimmed)];
      if (_searchHistory.length > _maxHistoryItems) {
        _searchHistory = _searchHistory.sublist(0, _maxHistoryItems);
      }
    });
  }

  void _removeFromHistory(String item) {
    setState(() {
      _searchHistory = _searchHistory.where((e) => e != item).toList();
    });
  }

  void _clearHistory() {
    setState(() => _searchHistory = []);
  }

  void _selectHistoryItem(String query) {
    _searchController.text = query;
    _onSearchChanged();
    _addToHistory(query);
  }

  void _tapSearchResult(_SearchResult result) {
    if (result.type == _ResultType.goal && result.id != null) {
      _addToHistory(_searchQuery);
      setState(() {
        _activeGoalId = result.id;
        _searching = false;
      });
      _searchController.clear();
      _searchFocusNode.unfocus();
    }
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

  // Public API for CLI
  void cliSwitchFace(String face) {
    setState(() {
      _selectedIndex = face == 'goal' ? 0 : face == 'todo' ? 2 : 1;
    });
  }

  void cliSwitchGoal(int goalId) {
    _switchGoal(goalId);
  }

  void cliNavigate(String route) {
    Navigator.pushNamed(context, route).then((_) => _loadGoals());
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: _buildDrawer(colorScheme),
      appBar: _searching
          ? _buildSearchAppBar(colorScheme)
          : _buildNormalAppBar(colorScheme),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats chips row (hidden in search mode)
          if (!_searching) _buildStatsChips(colorScheme),

          // Main content (state-driven)
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _searching
                  ? _buildSearchContent(colorScheme)
                  : _selectedIndex == 0
                      ? GoalFacePage(
                          key: ValueKey('goal_face_$_activeGoalId'),
                          goalService: widget.goalService,
                          habitService: widget.habitService,
                          frequencyService: _frequencyService,
                          todoService: widget.todoService,
                          activeGoalId: _activeGoalId,
                          onRequestCreateGoal: () =>
                              _navigateAndRefresh('/create-goal'),
                        )
                      : _selectedIndex == 1
                          ? HabitFacePage(
                              key: ValueKey('habit_face_${_activeGoalId}_$_habitFaceRefreshKey'),
                              goalService: widget.goalService,
                              habitService: widget.habitService,
                              frequencyService: _frequencyService,
                              activeGoalId: _activeGoalId,
                              onRequestCreateHabit: () =>
                                  _navigateAndRefresh('/create-habit'),
                            )
                          : TodoFacePage(
                              key: ValueKey('todo_face_$_todoFaceRefreshKey'),
                              todoService: widget.todoService,
                              goalService: widget.goalService,
                              habitService: widget.habitService,
                            ),
            ),
          ),
        ],
      ),
      floatingActionButton: _searching ? null : _buildFAB(colorScheme),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DRAWER — MemoFlow style: header + stats + heatmap + nav
  // ═══════════════════════════════════════════════════════════

  Widget _buildDrawer(ColorScheme colorScheme) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: App name (left) + Settings (right) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Text('Atoms',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, size: 22,
                        color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    tooltip: '设置',
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('设置页面待实现')),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Stats row: real data from HabitService / GoalService ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: _drawerDataLoaded
                  ? StatsRow(
                      items: [
                        StatItem(value: '$_habitCount', label: '习惯'),
                        StatItem(value: '$_goalCount', label: '目标'),
                        StatItem(value: '$_activeDays', label: '天'),
                      ],
                    )
                  : _loadingPlaceholder(colorScheme),
            ),

            // ── Heatmap: real data from logs table ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _drawerDataLoaded
                  ? Heatmap(
                      dailyCounts: _dailyCounts,
                      colorScheme: colorScheme,
                      onDayTap: (date, count) {
                        // 先关闭 Drawer，等一帧再弹 BottomSheet（避免动画冲突/context 失效）
                        Navigator.pop(context);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          DayDetailSheet.show(
                            context,
                            date: date,
                            habitService: widget.habitService,
                          );
                        });
                      },
                    )
                  : const SizedBox(height: 84),
            ),

            const Divider(height: 1),

            // ── Face switcher ──
            _drawerTile(
              icon: Icons.flag_outlined,
              selectedIcon: Icons.flag,
              label: '目标面',
              selected: _selectedIndex == 0,
              onTap: () => setState(() { _selectedIndex = 0; Navigator.pop(context); }),
              colorScheme: colorScheme,
            ),
            _drawerTile(
              icon: Icons.check_circle_outline,
              selectedIcon: Icons.check_circle,
              label: '习惯面',
              selected: _selectedIndex == 1,
              onTap: () => setState(() { _selectedIndex = 1; Navigator.pop(context); }),
              colorScheme: colorScheme,
            ),
            _drawerTile(
              icon: Icons.checklist_outlined,
              selectedIcon: Icons.checklist,
              label: 'Todo面',
              selected: _selectedIndex == 2,
              onTap: () => setState(() { _selectedIndex = 2; Navigator.pop(context); }),
              colorScheme: colorScheme,
            ),

            const Spacer(),

            // Footer
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'v0.1',
                  style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    IconData? selectedIcon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return ListTile(
      leading: Icon(selected ? (selectedIcon ?? icon) : icon,
          color: selected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6)),
      title: Text(label,
          style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? colorScheme.primary : colorScheme.onSurface)),
      selected: selected,
      selectedColor: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // NORMAL APP BAR — Hamburger + Title + Sort + Search
  // ═══════════════════════════════════════════════════════════

  PreferredSizeWidget _buildNormalAppBar(ColorScheme colorScheme) {
    return AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),  // hamburger menu
          tooltip: '菜单',
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: _buildGoalSelector(colorScheme),
      actions: [
        _buildSortMenu(colorScheme),
        IconButton(
          icon: const Icon(Icons.search_outlined),
          tooltip: '搜索',
          onPressed: _openSearch,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SEARCH APP BAR — Back arrow + Pill search bar + Cancel
  // ═══════════════════════════════════════════════════════════

  PreferredSizeWidget _buildSearchAppBar(ColorScheme colorScheme) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _closeSearch,
      ),
      title: _buildSearchField(colorScheme),
      actions: [
        TextButton(
          onPressed: _closeSearch,
          child: Text(
            '取消',
            style: TextStyle(color: colorScheme.primary, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search, size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (_) => _onSearchChanged(),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索目标、子目标...',
                hintStyle: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.4)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _onSearchChanged();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.close, size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SEARCH CONTENT — Landing (empty query) or Results (with query)
  // ═══════════════════════════════════════════════════════════

  Widget _buildSearchContent(ColorScheme colorScheme) {
    if (_searchQuery.trim().isEmpty) {
      return _buildSearchLanding(colorScheme);
    }

    if (_searchResults.isEmpty) {
      return Center(
        key: const ValueKey('search_empty'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_outlined, size: 64,
                color: colorScheme.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text('没有找到 "$_searchQuery" 的结果',
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      );
    }

    return ListView.separated(
      key: const ValueKey('search_results'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _searchResultCard(_searchResults[index], colorScheme);
      },
    );
  }

  Widget _buildSearchLanding(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = colorScheme.onSurface;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    return SingleChildScrollView(
      key: const ValueKey('search_landing'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          Row(
            children: [
              Text(
                '最近搜索',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_searchHistory.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _clearHistory,
                  icon: Icon(Icons.delete_outline, size: 18, color: textMuted),
                  tooltip: '清空搜索历史',
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_searchHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '暂无搜索历史',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            )
          else
            ..._searchHistory.map((item) => InkWell(
                  onTap: () => _selectHistoryItem(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 18, color: textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item,
                              style:
                                  TextStyle(fontSize: 14, color: textMain)),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _removeFromHistory(item),
                          icon: Icon(Icons.close, size: 18, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                )),

          const SizedBox(height: 18),

          // Suggested goals
          if (_goals.isNotEmpty) ...[
            Text(
              '推荐目标',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textMain,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _goals.take(6).map((goal) {
                return ActionChip(
                  avatar: Icon(Icons.flag_outlined, size: 16,
                      color: colorScheme.primary),
                  label: Text(goal.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: colorScheme.primary)),
                  side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onPressed: () {
                    _addToHistory(goal.name);
                    _searchController.text = goal.name;
                    _onSearchChanged();
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchResultCard(_SearchResult r, ColorScheme colorScheme) {
    final isGoal = r.type == _ResultType.goal;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _tapSearchResult(r),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isGoal
                      ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                      : colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isGoal ? Icons.flag_outlined : Icons.outlined_flag,
                  size: 18,
                  color: isGoal ? colorScheme.primary : colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(r.subtitle ?? '',
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              Chip(
                label: Text(isGoal ? '目标' : '子目标',
                    style: TextStyle(fontSize: 11, color: colorScheme.primary)),
                backgroundColor:
                    colorScheme.primaryContainer.withValues(alpha: 0.3),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SORT — rounded popup menu with check icon + up/down arrows
  // ═══════════════════════════════════════════════════════════

  Widget _buildSortMenu(ColorScheme colorScheme) {
    const options = [
      ('created_desc', '创建时间 ^'),
      ('created_asc', '创建时间 v'),
      ('modified_desc', '修改时间 v'),
      ('modified_asc', '修改时间 ^'),
    ];

    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort_outlined),
      tooltip: '排序',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      onSelected: (value) => setState(() => _sortBy = value),
      itemBuilder: (ctx) => options
          .map((opt) => PopupMenuItem<String>(
                value: opt.$1,
                height: 40,
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: _sortBy == opt.$1
                          ? Icon(Icons.check, size: 16, color: colorScheme.primary)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            _sortBy == opt.$1 ? FontWeight.w600 : FontWeight.w500,
                        color: _sortBy == opt.$1
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATS CHIPS
  // ═══════════════════════════════════════════════════════════

  Widget _buildStatsChips(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _statsChip(
              icon: Icons.bar_chart_outlined,
              label: '每周回顾',
              colorScheme: colorScheme,
              onTap: () => _navigateAndRefresh('/review'),
            ),
            const SizedBox(width: 8),
            _statsChip(
              icon: Icons.insights_outlined,
              label: '统计',
              colorScheme: colorScheme,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('统计面板待实现')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsChip({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      labelStyle: TextStyle(fontSize: 13, color: colorScheme.primary),
      side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: onTap,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // GOAL SELECTOR
  // ═══════════════════════════════════════════════════════════

  Widget _buildGoalSelector(ColorScheme colorScheme) {
    if (_goals.isEmpty) {
      return const Text('Atoms');
    }

    if (_goals.length == 1) {
      final goal = _goals.first;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              goal.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    final activeGoal =
        _goals.firstWhere((g) => g.id == _activeGoalId, orElse: () => _goals.first);

    return PopupMenuButton<int>(
      onSelected: _switchGoal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              activeGoal.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, color: colorScheme.onSurface),
        ],
      ),
      itemBuilder: (ctx) => _goals
          .map((g) => PopupMenuItem<int>(
                value: g.id,
                child: Row(
                  children: [
                    if (g.id == _activeGoalId)
                      Icon(Icons.check, size: 18, color: colorScheme.primary)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(g.name),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FAB — Large centered bottom button (MemoFlow Android style)
  // ═══════════════════════════════════════════════════════════

  Widget? _buildFAB(ColorScheme colorScheme) {
    // Todo 面自带添加按钮，不需要全局 FAB
    if (_selectedIndex == 2) return null;

    return FloatingActionButton.large(
      onPressed: () {
        if (_selectedIndex == 1) {
          _navigateAndRefresh('/create-habit',
              arguments: _activeGoalId);
        } else {
          _navigateAndRefresh('/create-goal');
        }
      },
      tooltip: _selectedIndex == 1 ? '添加习惯' : '添加目标',
      child: Icon(_selectedIndex == 1 ? Icons.add_task : Icons.flag, size: 28),
    );
  }

  /// Drawer 数据加载中的占位符
  Widget _loadingPlaceholder(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 20,
                height: 10,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ResultType { goal, milestone }

class _SearchResult {
  final _ResultType type;
  final int? id;
  final String title;
  final String? subtitle;

  _SearchResult({
    required this.type,
    this.id,
    required this.title,
    this.subtitle,
  });
}
