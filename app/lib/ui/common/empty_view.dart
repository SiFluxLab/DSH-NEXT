import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The one designed shape for empty, loading-failed and "not yet" states: a
/// soft round graphic, one line of title, an optional short message and at most
/// one button. Centred; never fills the screen with a spinner.
///
/// ```dart
/// EmptyView(
///   icon: AppIcons.time,
///   title: '还没有自动化任务',
///   message: '定时让 DSH 帮你跑一遍',
///   actionLabel: '新建',
///   onAction: create,
/// )
/// ```
///
/// - [icon] draws the standard round glass badge; [art] replaces it with any
///   widget (a brand mark, an illustration).
/// - [actionLabel] + [onAction] build the standard button; [action] takes a
///   ready-made widget instead (use one or the other).
/// - [compact] is the tighter size for narrow places (the drawer, a card).
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.icon,
    this.art,
    required this.title,
    this.message,
    this.action,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.padding,
  }) : assert(action == null || actionLabel == null, 'Pass either action or actionLabel, not both');

  final IconData? icon;
  final Widget? art;
  final String title;
  final String? message;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  /// Outer padding. Defaults to 32 horizontally (24 when [compact]).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    // vetta 的空态是「图标砖 + 13px 主文案 + 11px 副文案」：
    // 图标 40（砖 48、圆角 12、主色 10% 底），文字小、留白大，让空态**安静**。
    final badge = compact ? 40.0 : 48.0;
    Widget? graphic = art;
    if (graphic == null && icon != null) {
      graphic = Container(
        width: badge,
        height: badge,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
        ),
        child: Icon(
          icon,
          size: compact ? 18 : 22,
          color: theme.colorScheme.primary.withValues(alpha: 0.6),
        ),
      );
    }
    final button =
        action ??
        (actionLabel == null
            ? null
            : OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(0, compact ? 38 : 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: Text(actionLabel!),
              ));
    return Padding(
      padding: padding ?? EdgeInsets.symmetric(horizontal: compact ? 24 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (graphic != null) ...[graphic, SizedBox(height: compact ? 10 : 12)],
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (message case final message?) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  height: 1.5,
                  color: colors.textTertiary.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
          if (button != null) ...[SizedBox(height: compact ? 14 : 20), button],
        ],
      ),
    );
  }
}
