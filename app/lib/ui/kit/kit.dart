// 从 open-vetta 的 `packages/ui/src/*.tsx` 逐条搬过来的原语。
//
// 为什么单独建一层而不是改现有组件：vetta 的"精致"全在这些**行为细节**里——
// 按下平移 1px、焦点环 3px/30%、开关 18.4×32、按钮 32 高、输入框边框 60%…
// 这些值散落在各页面里会立刻失准，收在一处才能保证全站一致。
//
// 取值来源（源码原文 → 这里）：
//   button.tsx  base: rounded-lg border text-sm font-medium, active:translate-y-px
//               size default h-8 px-2.5 gap-1.5 · sm h-7 · xs h-6 · lg h-9 · icon size-8
//               variant default bg-foreground/ hover:opacity-85 · primary · outline
//                       field bg-muted text-[12px] · secondary · ghost · destructive
//   input.tsx   h-8 rounded-lg border-border/60 px-2.5, focus ring 3px primary/30
//   switch.tsx  h-[18.4px] w-[32px]（sm 14×24）, thumb 16/12, 命中区外扩 12×8
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// vetta 的几何与排版常量（px 直接对应 CSS）。
abstract final class Kit {
  /// 按钮高度档位。
  static const hXs = 24.0;
  static const hSm = 28.0;
  static const hMd = 32.0;
  static const hLg = 36.0;

  /// 圆角：只有两档——控件 8、容器 12。
  static const radiusControl = 8.0;
  static const radiusPanel = 12.0;

  /// 开关：18.4 × 32（sm 14 × 24），滑块 16 / 12。
  static const switchW = 32.0;
  static const switchH = 18.4;
  static const switchSmW = 24.0;
  static const switchSmH = 14.0;

  /// 焦点环：3px，30% 主色。
  static const focusRing = 3.0;

  /// 按下时整体下移 1px——这是它"有手感"的关键，比放大或变暗都更接近真按钮。
  static const pressOffset = 1.0;

  /// 字号：12（控件内文字）、13（列表标题）、14（正文）、11（元信息）。
  static const textMeta = 11.0;
  static const textControl = 12.0;
  static const textRow = 13.0;
  static const textBody = 14.0;

  /// 分区标题：`text-[15px] font-semibold text-foreground`（`SettingChrome` 的 `h2`）。
  static const sectionTitleSize = 15.0;

  /// 行高：单行 44、两行 56。
  ///
  /// vetta 的设置行是 `px-4 py-2.5` + 13px 正文 ≈ 40；手机触控要 44 才够拇指，
  /// 所以这里取 44 —— 但这一个数只写在这一处，设置页与列表页都从这里取，
  /// 免得两处各写一份再慢慢分叉。
  static const rowHeight = 44.0;
  static const rowHeightTwo = 56.0;

  /// 设置行右侧控件的宽度上限：`max-w-[min(100%,24rem)]` = 384。
  ///
  /// 上限挡住的是"值比标题还长"的情况（一串快捷入口名、一个主机地址）：超过
  /// 24rem 的值会换行，而不是把左边的标题挤成两三个字。
  static const controlMaxWidth = 384.0;
}

/// 动效闸门：新组件不许各自决定"要不要动"。
///
/// 系统"移除动画"（含 App 的省电降级）为真时一律零时长；光感档位关掉
/// "预见性动画"时，编排类动画也不再发生。这样新页面和老页面的手感一致。
abstract final class KitMotion {
  static Duration of(BuildContext context, [Duration fallback = AppMotion.quick]) {
    if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
    return fallback;
  }

  /// 编排（入场错峰）类动画是否允许。
  static bool choreography(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context) && Optics.of(context).anticipation;
}

enum KitButtonVariant { primary, standard, outline, field, secondary, ghost, destructive }

enum KitButtonSize { xs, sm, md, lg, icon, iconSm, iconLg }

/// 按钮。行为照 button.tsx：按下平移 1px、焦点环、disabled 50%。
class KitButton extends StatefulWidget {
  const KitButton({
    super.key,
    required this.onTap,
    this.label,
    this.icon,
    this.variant = KitButtonVariant.standard,
    this.size = KitButtonSize.md,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final String? label;
  final IconData? icon;
  final KitButtonVariant variant;
  final KitButtonSize size;
  final bool enabled;

  @override
  State<KitButton> createState() => _KitButtonState();
}

class _KitButtonState extends State<KitButton> {
  bool _down = false;

  double get _height => switch (widget.size) {
    KitButtonSize.xs => Kit.hXs,
    KitButtonSize.sm || KitButtonSize.iconSm => Kit.hSm,
    KitButtonSize.lg || KitButtonSize.iconLg => Kit.hLg,
    _ => Kit.hMd,
  };

  bool get _iconOnly => widget.label == null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, border) = switch (widget.variant) {
      KitButtonVariant.primary => (scheme.primary, scheme.onPrimary, Colors.transparent),
      KitButtonVariant.standard => (scheme.onSurface, scheme.surface, Colors.transparent),
      KitButtonVariant.outline => (Colors.transparent, scheme.onSurface, scheme.outlineVariant),
      KitButtonVariant.field => (scheme.surfaceContainerHigh, scheme.onSurface, Colors.transparent),
      KitButtonVariant.secondary => (scheme.secondaryContainer, scheme.onSurface, Colors.transparent),
      KitButtonVariant.ghost => (Colors.transparent, scheme.onSurfaceVariant, Colors.transparent),
      KitButtonVariant.destructive => (scheme.error.withValues(alpha: 0.12), scheme.error, Colors.transparent),
    };
    final radius = BorderRadius.circular(Kit.radiusControl);
    final content = Container(
      height: _height,
      padding: _iconOnly
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 10),
      width: _iconOnly ? _height : null,
      decoration: BoxDecoration(color: background, borderRadius: radius, border: Border.all(color: border, width: 1)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon case final icon?) Icon(icon, size: widget.size == KitButtonSize.xs ? 12 : 16, color: foreground),
          if (widget.label case final label?) ...[
            if (widget.icon != null) const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.variant == KitButtonVariant.field ? Kit.textControl : Kit.textBody,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: foreground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: widget.enabled ? () => setState(() => _down = false) : null,
          onTapUp: widget.enabled
              ? (_) {
                  setState(() => _down = false);
                  widget.onTap?.call();
                }
              : null,
          child: AnimatedContainer(
            duration: KitMotion.of(context),
            curve: AppMotion.swift,
            // 按下整体下移 1px：这一像素是"按到了实体"的全部来源。
            transform: Matrix4.translationValues(0, _down ? Kit.pressOffset : 0, 0),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// 开关：18.4 × 32，滑块 16，开着填主色；命中区比可见范围大一圈。
class KitSwitch extends StatelessWidget {
  const KitSwitch({super.key, required this.value, required this.onChanged, this.small = false});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool small;

  /// 命中区在轨道外各留的距离（`after:-inset-x-3 -inset-y-2`）。
  ///
  /// 这一段是**布局**的一部分，不是看不见的手势区：把开关放进行里时，行的
  /// 右内边距要减掉 [hitPadX]，轨道才会和右侧的值、箭头停在同一竖线上
  /// （M3 开关的轨道只在盒子里内缩 4，换成这个开关后原来那 4 就不成立了）。
  static const hitPadX = 12.0;
  static const hitPadY = 8.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = small ? Kit.switchSmW : Kit.switchW;
    final h = small ? Kit.switchSmH : Kit.switchH;
    final thumb = h - 2;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          // after:-inset-x-3 -inset-y-2 → 左右各外扩 12、上下各 8 的命中区。
          padding: const EdgeInsets.symmetric(horizontal: hitPadX, vertical: hitPadY),
          child: AnimatedContainer(
            duration: KitMotion.of(context),
            curve: AppMotion.swift,
            width: w,
            height: h,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: value ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(h / 2),
            ),
            child: AnimatedAlign(
              duration: KitMotion.of(context),
              curve: AppMotion.swift,
              alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              child: Container(
                width: thumb,
                height: thumb,
                decoration: BoxDecoration(
                  color: value ? scheme.onPrimary : scheme.surface,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 输入框：32 高、圆角 8、边框 60% 细线，聚焦时 3px/30% 主色环。
class KitInput extends StatefulWidget {
  const KitInput({super.key, required this.controller, this.hint, this.onChanged, this.focusNode});

  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  State<KitInput> createState() => _KitInputState();
}

class _KitInputState extends State<KitInput> {
  late final FocusNode _node = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    _node.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _node.removeListener(_refresh);
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focused = _node.hasFocus;
    return AnimatedContainer(
      duration: KitMotion.of(context),
      height: Kit.hMd,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Kit.radiusControl),
        border: Border.all(
          color: focused ? scheme.primary.withValues(alpha: 0.6) : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: focused
            ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.3), spreadRadius: Kit.focusRing / 2, blurRadius: Kit.focusRing)]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      child: TextField(
        controller: widget.controller,
        focusNode: _node,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: Kit.textBody),
        cursorHeight: math.min(18, Kit.textBody * 1.3),
        decoration: InputDecoration.collapsed(hintText: widget.hint),
      ),
    );
  }
}

/// 浮层的统一皮肤（`packages/ui/src/utils.ts` 的四段常量在这里各对应一条）。
abstract final class KitSurface {
  /// `PANEL_SHADOW_CLASS`：两层小半径柔影，没有外边框。
  /// 0 16px 40px -12px rgb(0 0 0 / 0.10) + 0 2px 8px -2px rgb(0 0 0 / 0.05)
  static List<BoxShadow> panelShadow() => const [
    BoxShadow(color: Color(0x1A000000), blurRadius: 40, offset: Offset(0, 16), spreadRadius: -12),
    BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2), spreadRadius: -2),
  ];

  /// `OVERLAY_BACKDROP_CLASS`：黑 20% + 12px 模糊。
  static const backdropAlpha = 0.20;
  static const backdropBlur = 12.0;

  /// `FLOATING_SURFACE_CLASS`：圆角 16、popover 底色、深色下补 1px 白色 10% 内环。
  static const floatingRadius = 16.0;
}

/// muted 阶梯：vetta 只用固定几档透明度做层级（100/80/70/65/60/55/45/40）。
abstract final class KitMuted {
  static const full = 1.0;
  static const a80 = 0.80;
  static const a70 = 0.70;
  static const a65 = 0.65;
  static const a60 = 0.60;
  static const a55 = 0.55;
  static const a45 = 0.45;
  static const a40 = 0.40;
}

/// 分区卡：`overflow-hidden rounded-xl border border-border bg-card`。
///
/// 注意它和 [FlatPanel] 的差别：vetta 的实体卡用的是**实色 border**（不用半透明），
/// 因为它的角色是"这里是一个界定清楚的分区"；半透明边框只给输入框、菜单这类控件。
class KitCard extends StatelessWidget {
  const KitCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Kit.radiusPanel),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(Kit.radiusPanel), child: child),
    );
  }
}

/// 卡片里的多行：行与行之间一条 0.5px 细线（`SettingRow` 的 `border-b` 落点）。
///
/// vetta 的分区卡在每行底部画 `border-b border-border`，末行去掉；手机上 1px 会和
/// 卡自己的 1px 外框抢分量，所以取半像素：还是一道线，但不是两道一样粗的线叠在
/// 一起。这条线必须**画出来**——之前用的是 `SizedBox(height: 0.5)` 的缝，而行本身
/// 没有底色，缝里露出的是卡的底面，等于什么都没画，一列行就读成了一整块。
class KitRowList extends StatelessWidget {
  const KitRowList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final line = ColoredBox(color: Theme.of(context).colorScheme.outlineVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) SizedBox(height: 0.5, child: line),
          child,
        ],
      ],
    );
  }
}

/// 分区标题：vetta 的 SectionHeader 是 `text-[15px] font-semibold` + 下方 12。
class KitSectionHeader extends StatelessWidget {
  const KitSectionHeader({super.key, required this.title, this.note});

  final String title;

  /// 计数或补充说明，`text-[12px] muted`，与标题同一基线。
  final String? note;

  /// 分区标题的字：`text-[15px] font-semibold text-foreground`。
  ///
  /// 弹层 / 抽屉里的分组标题也取这一份（`groupTitleStyle` 转调这里）：同一个
  /// "分组"在卡片上和弹层里长得不一样，是最容易被看出来的一种不一致。
  static TextStyle? titleStyle(BuildContext context) => TextStyle(
    fontSize: Kit.sectionTitleSize,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: Theme.of(context).colorScheme.onSurface,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: titleStyle(context))),
          if (note case final note?)
            Text(
              note,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant.withValues(alpha: KitMuted.a60),
              ),
            ),
        ],
      ),
    );
  }
}

/// 卡片角标：`h-5 rounded-full px-2 text-[10px] font-semibold` + 15% 底色。
class KitChip extends StatelessWidget {
  const KitChip({super.key, required this.label, this.color, this.dot = false});

  final String label;
  final Color? color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: tint, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1.2, color: tint),
          ),
        ],
      ),
    );
  }
}

/// 页内分段（prism 的 `.ag-cs-home-tab` 规格）。
///
/// 每枚自带胶囊底，**没有**滑动指示条：高 24（字号 12/行高 18 + 上下 2 + 左右 9），
/// 圆角 999；未选是次字色 + 透明边，悬停前景 5.5%，选中 前景 9% 底 + 前景 9.5% 边 + w500。
/// 过渡 120ms —— 比分段滑块快得多，因为它只是"点亮"，不是"搬东西"。
class KitSegmented<T> extends StatelessWidget {
  const KitSegmented({super.key, required this.items, required this.value, required this.onChanged});

  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 2),
          _Segment(
            label: item.$2,
            selected: item.$1 == value,
            onTap: () => onChanged(item.$1),
            fg: fg,
          ),
        ],
      ],
    );
  }
}

class _Segment extends StatefulWidget {
  const _Segment({required this.label, required this.selected, required this.onTap, required this.fg});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color fg;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = widget.fg;
    final background = widget.selected
        ? tint.withValues(alpha: 0.09)
        : _hover
        ? tint.withValues(alpha: 0.055)
        : Colors.transparent;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: KitMotion.of(context, const Duration(milliseconds: 120)),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: widget.selected ? tint.withValues(alpha: 0.095) : Colors.transparent,
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                height: 18 / 12,
                fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w400,
                color: widget.selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 双极胶囊（prism 的 `.ag-prism-sb-seg` 规格）：两格，滑块 300ms 滑过去。
///
/// 这一枚是"搬东西"而不是"点亮"，所以用它自己的曲线
/// `cubic-bezier(0.34, 1.24, 0.64, 1)`——带一点回弹，手感比 linear 活。
class KitDualToggle extends StatelessWidget {
  const KitDualToggle({
    super.key,
    required this.left,
    required this.right,
    required this.rightSelected,
    required this.onChanged,
  });

  final (IconData, String) left;
  final (IconData, String) right;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  /// 300ms + 回弹。
  static const curve = Cubic(0.34, 1.24, 0.64, 1);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final track = dark ? Colors.white.withValues(alpha: 0.052) : const Color(0xFF0F172A).withValues(alpha: 0.055);
    final knob = dark ? Colors.white.withValues(alpha: 0.13) : Colors.white;
    return SizedBox(
      height: 31,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            AnimatedAlign(
              duration: KitMotion.of(context, const Duration(milliseconds: 300)),
              curve: curve,
              alignment: rightSelected ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: knob, borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(child: _Half(item: left, selected: !rightSelected, onTap: () => onChanged(false))),
                  Expanded(child: _Half(item: right, selected: rightSelected, onTap: () => onChanged(true))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({required this.item, required this.selected, required this.onTap});

  final (IconData, String) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.$1, size: 12.5, color: selected ? scheme.onSurface : scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              item.$2,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
