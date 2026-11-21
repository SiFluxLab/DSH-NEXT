// The drawer's conversation row and section label.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../state/session_attention_state.dart';
import '../../common/haptics.dart';
import '../../common/status_dot.dart';
import '../../kit/kit.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../sessions_drawer.dart' show sessionSelectionColor;

/// One conversation row: 44 high, the highlight on the 10 line, the title on
/// the 20 line (plus [indent] inside a folder). At the end, one marker at
/// most: what it waits for (待确认 / 待回答), a breathing dot while it works,
/// or a quiet ring while it moved on since it was last seen. In multi-select a
/// check slides in before the title.
///
/// 按住的三个层次（手机上没有 hover，所以都挂在"按住"上）：
/// 1. 手一落下就是一层 4.5% 的前景薄雾（不是水波纹：44 的行里水波会盖住标题）；
/// 2. 按住 [holdDelay] 之后整行放大 1.5%，并给一次 selectionClick——这是"我要对它
///    做点什么"的确认，不是点开对话的反馈；
/// 3. 同一刻行尾那枚标记换成 ⋯：告诉手指"这里还有一整套动作"，
///    下一帧弹出的动作面板就不是凭空出现的。
class SessionTile extends StatefulWidget {
  const SessionTile({
    super.key,
    required this.title,
    required this.running,
    required this.current,
    required this.onTap,
    required this.onLongPress,
    this.pending,
    this.unread = false,
    this.pinned = false,
    this.indent = 0,
    this.selecting = false,
    this.selected = false,
    this.landed = false,
  });

  final String title;
  final bool running;

  /// The open conversation (soft fill; ignored while selecting).
  final bool current;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final PendingKind? pending;
  final bool unread;

  /// Shown as a small pin (inside folders; elsewhere 置顶 says it).
  final bool pinned;

  /// Content inset from the 20 line (folder members: [folderIndent]).
  final double indent;
  final bool selecting;
  final bool selected;

  /// A conversation that just arrived in the list: one 200ms highlight, once.
  final bool landed;

  static const height = 44.0;

  /// A folder's glyph (20) plus its gap (10): members' titles line up with
  /// the folder's name.
  static const folderIndent = 30.0;

  /// Width of the check slot while selecting (a 20 circle and a 10 gap).
  static const checkSlot = 30.0;

  /// Size of the quiet markers at the end of the row.
  static const dot = 7.0;

  /// 按住多久算"要动这一行"。长过滚动时的按压判定（[AppMotion.press]），
  /// 短于系统的长按（500ms）：抬起来的动作落在两者之间，手感才不打架。
  static const holdDelay = Duration(milliseconds: 320);

  /// 按住时的放大：1.5%，看得出，但不会把相邻的行挤开。
  static const holdScale = 1.015;

  @override
  State<SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<SessionTile> {
  bool _held = false;
  Timer? _hold;

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  /// [InkWell] 的高亮就是"手指按在这一行上"（滚动一开就取消），
  /// 所以按住的时间直接从这里量，不必再抢一个手势识别器。
  void _onHighlight(bool down) {
    _hold?.cancel();
    if (!down) {
      if (_held) setState(() => _held = false);
      return;
    }
    // 只有真的能对它做事（有长按）才提前给信号。
    if (widget.onLongPress == null) return;
    _hold = Timer(SessionTile.holdDelay, () {
      if (!mounted) return;
      setState(() => _held = true);
      // 触感走全站唯一的出口（[Haptics]）：选择类，最轻的那一档。
      Haptics.selection();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = DshColors.of(context);
    final shape = Squircle.border(AppShape.md);
    final current = widget.current && !widget.selecting;
    final highlighted = widget.selecting ? widget.selected : current;
    final Widget? marker = switch ((widget.pending, widget.running, widget.unread)) {
      (final PendingKind kind, _, _) => Text(
        kind.label,
        key: const ValueKey('pending'),
        style: theme.textTheme.labelMedium?.copyWith(color: colors.warning, fontWeight: FontWeight.w500),
      ),
      (_, true, _) => const StatusDot(key: ValueKey('running'), tone: StatusTone.busy, size: SessionTile.dot),
      (_, _, true) => const _UnreadDot(key: ValueKey('unread')),
      _ => null,
    };
    // 按住时行尾给一个 ⋯：动作面板出现之前，先让手指知道"这里能展开"。
    final trailing = _held && widget.onLongPress != null
        ? Icon(
            AppIcons.more,
            key: const ValueKey('held'),
            size: 16,
            color: colors.textTertiary.withValues(alpha: KitMuted.a80),
          )
        : marker;
    // 大多数行什么都没有要念的：先走这条快路，别为一句等于标题的话
    // 每行建一次 List、拼一次 String（列表每收到一次未读/待确认更新就会重建全部行）。
    final label = widget.pending == null && !widget.running && !widget.unread && !widget.pinned
        ? widget.title
        : [
            widget.title,
            ?widget.pending?.label,
            if (widget.pending == null && widget.running) l10n.shellCurrentlyRunning,
            if (widget.pending == null && !widget.running && widget.unread) l10n.shellUnread,
            if (widget.pinned) l10n.shellPinned,
          ].join(l10n.shellSemanticsSeparator);
    // 选中底色不随动画帧变，只有透明度在动：颜色在 builder 外面算一次，
    // 别让每一帧都去问一次主题。
    final fill = sessionSelectionColor(context);
    final row = Row(
      children: [
        _CheckSlot(selecting: widget.selecting, selected: widget.selected),
        Expanded(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // 14/500：列表标题只有这一档（规格 theme-ui §3.1 的 13/medium
            // 在手机触控密度上抬一档）。当前会话再加到 600，是规格里
            // 「激活行 font-semibold」的那一条 —— 层级靠字重，不靠字号。
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 14,
              height: 1.4,
              color: scheme.onSurface,
              fontWeight: current ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        if (widget.pinned) ...[
          const SizedBox(width: 8),
          Icon(AppIcons.pinActive, size: 14, color: colors.textTertiary.withValues(alpha: KitMuted.a80)),
        ],
        AnimatedSwitcher(
          duration: KitMotion.of(context, AppMotion.quick),
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.centerRight, children: [...previous, ?current]),
          child: trailing == null
              ? const SizedBox.shrink(key: ValueKey('none'))
              : Padding(key: trailing.key, padding: const EdgeInsets.only(left: 10), child: trailing),
        ),
      ],
    );
    return Semantics(
      selected: highlighted,
      checked: widget.selecting ? widget.selected : null,
      label: label,
      button: true,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _held ? SessionTile.holdScale : 1.0),
          duration: KitMotion.of(context, AppMotion.quick),
          curve: AppMotion.swift,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onHighlightChanged: _onHighlight,
            customBorder: shape,
            // 水波纹换成一层薄雾：玻璃抽屉里的行不该有 M3 的墨水扩散。
            splashFactory: rowSplash(context),
            highlightColor: Colors.transparent,
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? scheme.onSurface.withValues(alpha: 0.045)
                  : null,
            ),
            // Ink (not a container's decoration), so the wash draws over the
            // fill; the fill fades in and out.
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: highlighted ? 1 : 0),
              duration: KitMotion.of(context, AppMotion.quick),
              curve: AppMotion.std,
              builder: (context, t, child) {
                return Ink(
                  decoration: ShapeDecoration(
                    color: fill.withValues(alpha: fill.a * t),
                    shape: shape,
                  ),
                  height: SessionTile.height,
                  padding: EdgeInsetsDirectional.only(start: 10 + widget.indent, end: 10),
                  child: child,
                );
              },
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                // 左脊画在行的 13 线上、正文的 20 线之外：它要让出 7，不能挤动文字。
                clipBehavior: Clip.none,
                children: [
                  // 当前会话的左脊：一条 2.5 × 16 的主色竖条。
                  // 强调色只有这一处，所以"我在这儿"不靠整行染色，靠这一条。
                  if (current)
                    PositionedDirectional(
                      start: -7,
                      top: 14,
                      width: _CurrentSpine.width,
                      height: _CurrentSpine.height,
                      child: _CurrentSpine(color: scheme.primary),
                    ),
                  // 刚落地的会话：一次性 200ms 的高光，从 9% 走到 0，之后不再有帧。
                  // 画在文字**下面**（先入栈），压在上面会把标题也染一层。
                  if (widget.landed) Positioned.fill(child: _Landing(color: scheme.primary, shape: shape)),
                  row,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The current conversation's 2.5 × 16 bar, on the row's inner edge.
class _CurrentSpine extends StatelessWidget {
  const _CurrentSpine({required this.color});

  final Color color;

  /// 2.5 宽（发丝级的下限，屏幕上就是 2–3 个物理像素）。
  static const width = 2.5;

  /// 16 高：比一行的 44 矮得多，读作"标记"而不是"一格"。
  static const height = 16.0;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
  );
}

/// A new conversation landing in the list: one shot, 200ms bright then out.
///
/// 它只播一次：[SessionTile.landed] 由列表在"这一行是刚出现的"那一帧给，
/// 播完就撤。空闲时不留任何动画控制器（[TweenAnimationBuilder] 停下来就不再有帧）。
class _Landing extends StatelessWidget {
  const _Landing({required this.color, required this.shape});

  final Color color;
  final ShapeBorder shape;

  /// 亮着的这一段：[AppMotion.commit]（320ms，"落定"那一档）的前 62%。
  static const _bright = 0.62;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: KitMotion.of(context, AppMotion.commit),
        // 200ms 走到 0（320 × 0.62），后面那段静止：落下就停，不拖着发亮。
        curve: const Interval(0, _bright, curve: AppMotion.enter),
        builder: (context, t, _) => DecoratedBox(
          decoration: ShapeDecoration(color: color.withValues(alpha: 0.09 * t), shape: shape),
        ),
      ),
    );
  }
}

/// 未读：6 的实点 + 一圈 1px 的淡环。
///
/// 环是"还没读的那口气"：比单纯放大点更安静，也不会凭空多出第二种强调色；
/// 和旁边"运行中"的实心呼吸点一眼就能分开。
class _UnreadDot extends StatelessWidget {
  const _UnreadDot({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox.square(
      dimension: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: KitMuted.a70),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
        ),
      ),
    );
  }
}

/// The check that slides in before the title while selecting: a 20 ring,
/// filled with ink and a tick once chosen (ink, not the brand colour — the
/// drawer keeps one primary element).
class _CheckSlot extends StatelessWidget {
  const _CheckSlot({required this.selecting, required this.selected});

  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selecting ? 1 : 0),
      duration: KitMotion.of(context, AppMotion.standard),
      curve: AppMotion.std,
      builder: (context, t, child) {
        if (t == 0) return const SizedBox.shrink();
        return SizedBox(
          width: SessionTile.checkSlot * t,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: SessionTile.checkSlot,
              maxWidth: SessionTile.checkSlot,
              child: Opacity(opacity: t, child: child),
            ),
          ),
        );
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedSwitcher(
          duration: KitMotion.of(context, AppMotion.quick),
          child: selected
              ? DecoratedBox(
                  key: const ValueKey('on'),
                  decoration: ShapeDecoration(color: scheme.onSurface, shape: const CircleBorder()),
                  child: SizedBox.square(
                    dimension: 20,
                    child: Icon(AppIcons.selected, size: 14, color: scheme.surface),
                  ),
                )
              : DecoratedBox(
                  key: const ValueKey('off'),
                  decoration: ShapeDecoration(
                    shape: CircleBorder(
                      side: BorderSide(color: scheme.onSurfaceVariant.withValues(alpha: 0.55), width: 1.5),
                    ),
                  ),
                  child: const SizedBox.square(dimension: 20),
                ),
        ),
      ),
    );
  }
}

/// A section label in the drawer list: small, faint, on the 20 line.
///
/// 两级：[quiet] 是时间分组（今天 / 昨天），比结构分组（置顶、文件夹）再轻一档——
/// 结构是"这些是你排的"，时间是"这些是系统排的"，读的时候不该一样重。
/// 列表滚动时字距收 0.5：动起来的标题收紧一点，停下来的标题放开，
/// 这一下让"在滚"和"停下了"有分别，也替掉了会晃眼的吸顶放大。
class DrawerEyebrow extends StatelessWidget {
  const DrawerEyebrow(this.text, {super.key, this.quiet = false, this.scrolling = false});

  final String text;
  final bool quiet;
  final bool scrolling;

  /// 字距的两档（em）。
  static const _wide = 0.7;
  static const _tight = 0.2;

  @override
  Widget build(BuildContext context) {
    final base = DshColors.of(context).textTertiary;
    final color = quiet ? base.withValues(alpha: KitMuted.a80) : base;
    final style = (quiet ? AppType.eyebrow(color: color).copyWith(fontSize: 11.5) : AppType.eyebrow(color: color))
        .copyWith(letterSpacing: scrolling ? _tight : _wide);
    return Padding(
      padding: EdgeInsets.fromLTRB(10, quiet ? 14 : 18, 10, 6),
      child: Semantics(
        header: true,
        child: AnimatedDefaultTextStyle(
          duration: KitMotion.of(context, AppMotion.standard),
          curve: AppMotion.std,
          style: style,
          child: Text(text),
        ),
      ),
    );
  }
}
