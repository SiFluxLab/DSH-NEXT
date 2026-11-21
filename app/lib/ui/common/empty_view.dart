import 'package:flutter/material.dart';

import '../kit/kit.dart';
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
    // vetta 的空态是「图标砖 + 13px 主文案 + 11px 副文案」三段式：
    // 砖 48、圆角 12、主色 10% 底，砖里的图标 24 再淡到 40%（`text-primary/40`）——
    // 图案本身永远比砖更淡，空态才**安静**。文字小、留白大，不靠大字号撑场面。
    final badge = compact ? 40.0 : 48.0;
    Widget? graphic = art;
    if (graphic == null && icon != null) {
      graphic = Container(
        width: badge,
        height: badge,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(compact ? AppShape.sm : Kit.radiusPanel),
        ),
        child: Icon(
          icon,
          size: compact ? 18 : 24,
          color: theme.colorScheme.primary.withValues(alpha: KitMuted.a40),
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
              fontSize: Kit.textRow,
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
                  fontSize: Kit.textMeta,
                  height: 1.5,
                  // 三级文字本来就是为"承载信息但不能抢"定的；再往下压透明度就
                  // 掉到 4.5 对比度以下了，所以这里不再叠一层 75%。
                  color: colors.textTertiary,
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
