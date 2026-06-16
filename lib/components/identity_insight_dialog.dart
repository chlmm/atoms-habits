import 'package:flutter/material.dart';

/// Dialog that shows an identity insight suggestion.
///
/// Returns:
///   'accepted' if user accepts
///   modified text if user chooses to modify
///   null if user dismisses
Future<String?> showIdentityInsightDialog(
  BuildContext context, {
  required String habitName,
  required int totalCompleted,
  required String suggestedIdentity,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _IdentityInsightDialog(
      habitName: habitName,
      totalCompleted: totalCompleted,
      suggestedIdentity: suggestedIdentity,
    ),
  );
}

class _IdentityInsightDialog extends StatefulWidget {
  final String habitName;
  final int totalCompleted;
  final String suggestedIdentity;

  const _IdentityInsightDialog({
    required this.habitName,
    required this.totalCompleted,
    required this.suggestedIdentity,
  });

  @override
  State<_IdentityInsightDialog> createState() => _IdentityInsightDialogState();
}

class _IdentityInsightDialogState extends State<_IdentityInsightDialog> {
  bool _editing = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(children: [
        Icon(Icons.psychology, color: colorScheme.primary),
        const SizedBox(width: 8),
        const Text('身份的浮现'),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('你已经完成了 ${widget.totalCompleted} 次「${widget.habitName}」。'),
          const SizedBox(height: 16),
          const Text('你正在变成一个'),
          const SizedBox(height: 8),
          _editing
              ? TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submitModified(),
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(60),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.suggestedIdentity,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('暂时不要'),
        ),
        if (!_editing)
          TextButton(
            onPressed: () {
              _controller.text = widget.suggestedIdentity;
              setState(() => _editing = true);
            },
            child: const Text('换一个说法'),
          ),
        if (_editing)
          FilledButton(
            onPressed: _submitModified,
            child: const Text('确认'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.pop(context, 'accepted'),
            child: const Text('认可这个身份'),
          ),
      ],
    );
  }

  void _submitModified() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }
}
