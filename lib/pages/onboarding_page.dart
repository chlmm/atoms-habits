import 'package:flutter/material.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../data/demo_data.dart';
import '../components/page_indicator.dart';

class OnboardingPage extends StatefulWidget {
  final GoalService goalService;
  final HabitService habitService;

  const OnboardingPage({
    super.key,
    required this.goalService,
    required this.habitService,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  bool _loading = false;
  int _currentPage = 0;
  static const _totalPages = 5;

  static const _demoGoal = '完成双力臂';

  static const _demoMilestones = [
    '完成 1 个引体向上',
    '完成 10 个标准引体',
    '完成 10 个变体引体',
    '完成 1 个双力臂',
  ];

  static const _demoActions = [
    '负重悬吊 30秒',
    '弹力带辅助引体 5×3',
    '离心引体下降 5×3',
    '拉伸 30秒',
    '平板支撑 60秒',
    '死虫式 3×10',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _playDemo() async {
    setState(() => _loading = true);
    try {
      await insertDemoData(
        goalService: widget.goalService,
        habitService: widget.habitService,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('演示数据写入失败：$e')),
      );
      setState(() => _loading = false);
    }
  }

  void _createMyOwn() {
    Navigator.pushReplacementNamed(context, '/create-goal');
  }

  void _skipDemo() {
    Navigator.pushReplacementNamed(context, '/create-goal');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                '正在准备演示数据...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildCardGoal(colorScheme),
                _buildCardMilestones(colorScheme),
                _buildCardActionPlans(colorScheme),
                _buildCardHabits(colorScheme),
                _buildCardWelcome(colorScheme),
              ],
            ),
          ),
          PageIndicator(
            currentPage: _currentPage,
            totalPages: _totalPages,
            onDotTap: (index) => _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }

  // ── Card 1: Goal ────────────────────────────────────

  Widget _buildCardGoal(ColorScheme colorScheme) {
    return _cardShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            '一切从你想达成的结果开始。',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              _demoGoal,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '比如可以是一个具体的成果：',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '· 减掉 10 公斤\n· 每天醒来精力充沛\n· 读完 20 本书',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          _bottomNav(
            left: TextButton(
              onPressed: _skipDemo,
              child: const Text('跳过演示，我自己来'),
            ),
            right: FilledButton(
              onPressed: _nextPage,
              child: const Text('下一步'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card 2: Milestones ──────────────────────────────

  Widget _buildCardMilestones(ColorScheme colorScheme) {
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            '然后拆成阶段性关口。',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '每过一个，你就前进一截。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < _demoMilestones.length; i++)
            _milestoneItem(
              colorScheme,
              index: i,
              name: _demoMilestones[i],
              isActive: i == 0,
            ),
          const SizedBox(height: 16),
          Text(
            '第一个自动激活，后面的达标后才解锁。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
          const Spacer(),
          _bottomNav(
            left: OutlinedButton(
              onPressed: _prevPage,
              child: const Text('上一步'),
            ),
            right: FilledButton(
              onPressed: _nextPage,
              child: const Text('下一步'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card 3: Action Plans ────────────────────────────

  Widget _buildCardActionPlans(ColorScheme colorScheme) {
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            '针对第一个关口',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '"完成 1 个引体向上"',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '列出所有需要做的行为。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 16),
          for (final action in _demoActions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.circle_outlined,
                      size: 8, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(action,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            '先列出来，不急打包。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
          const Spacer(),
          _bottomNav(
            left: OutlinedButton(
              onPressed: _prevPage,
              child: const Text('上一步'),
            ),
            right: FilledButton(
              onPressed: _nextPage,
              child: const Text('下一步'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card 4: Habits ──────────────────────────────────

  Widget _buildCardHabits(ColorScheme colorScheme) {
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            '把这些行动按频率组织成习惯。',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 20),
          _habitDemoCard(
            colorScheme,
            name: '练背计划',
            frequency: '每两天',
            actions: _demoActions.sublist(0, 4).toList(),
            safetyValve: '如果太累：挂上单杠 30秒',
          ),
          const SizedBox(height: 12),
          _habitDemoCard(
            colorScheme,
            name: '核心训练',
            frequency: '每周两次',
            actions: _demoActions.sublist(4).toList(),
            safetyValve: null,
          ),
          const SizedBox(height: 16),
          Text(
            '还有安全阀：不想动时也有退路。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
          const Spacer(),
          _bottomNav(
            left: OutlinedButton(
              onPressed: _prevPage,
              child: const Text('上一步'),
            ),
            right: FilledButton(
              onPressed: _nextPage,
              child: const Text('下一步'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card 5: Welcome ─────────────────────────────────

  Widget _buildCardWelcome(ColorScheme colorScheme) {
    return _cardShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(Icons.rocket_launch_outlined, size: 64, color: colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            '学会了。现在该你了。',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '你有两个选择：',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _playDemo,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.play_circle_outline, color: colorScheme.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('先玩一遍演示目标',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            '用预设的"完成双力臂"体验打勾和进度',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _createMyOwn,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: colorScheme.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('创建我自己的目标',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            '走一遍刚才的流程，设定属于我的目标',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '两个都可以。随时从主界面新建。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────

  Widget _cardShell({required Widget child}) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: child,
      ),
    );
  }

  Widget _bottomNav({required Widget left, required Widget right}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [left, right],
      ),
    );
  }

  Widget _milestoneItem(
    ColorScheme colorScheme, {
    required int index,
    required String name,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 16,
            color: isActive ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${index + 1}  $name',
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitDemoCard(
    ColorScheme colorScheme, {
    required String name,
    required String frequency,
    required List<String> actions,
    String? safetyValve,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(frequency,
                    style: Theme.of(context).textTheme.labelSmall),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.check_box_outlined,
                      size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(action,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          if (safetyValve != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.shield_outlined,
                    size: 16,
                    color: Colors.orange.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    safetyValve,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.orange.shade600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

}
