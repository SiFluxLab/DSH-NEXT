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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../common/haptics.dart';
import '../theme/theme.dart';

// 新原语各自成文件（骨架屏、入场编排），但从这里转出口：调用方只要
// `import '../kit/kit.dart';` 就全都拿得到，不必为了一个新件再加一行 import。
export 'kit_reveal.dart';
export 'kit_skeleton.dart';

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

  /// 松手回弹时**越过**静止位置的距离（0.5px）。
  ///
  /// 回弹只走 60ms 而且要过冲，所以不能用 [AppMotion.springCurve]（它 1.9% 的
  /// 过冲落在 1px 上只有 0.02px，看不见），必须写成显式关键帧：
  /// `1px → -0.5px → 0`，见 [KitPress]。
  static const pressRebound = 0.5;

  /// 开关切换时轨道横向鼓起的比例（1.5%，160ms 内鼓满再收回）。
  static const toggleBulge = 0.015;

  /// 滑块搬家途中横向压缩的比例（scaleX 0.96）。
  ///
  /// 真东西被推着走时，前后两端会被挤一下；少了这一下，滑块就只是"一个矩形
  /// 平移了"，视觉上读不出它是被"搬"过去的。
  static const slideSqueeze = 0.04;

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
  static const rowHeight = 52.0;
  static const rowHeightTwo = 64.0;

  /// 设置行右侧控件的宽度上限：`max-w-[min(100%,24rem)]` = 384。
  ///
  /// 上限挡住的是"值比标题还长"的情况（一串快捷入口名、一个主机地址）：超过
  /// 24rem 的值会换行，而不是把左边的标题挤成两三个字。
  static const controlMaxWidth = 384.0;
}

/// 动效闸门：新组件不许各自决定"要不要动"，也不许各自写时长。
///
/// 系统"移除动画"（含 App 的省电降级）为真时一律零时长；光感档位关掉
/// "预见性动画"时，编排类动画也不再发生。这样新页面和老页面的手感一致。
///
/// 下面的常量是 kit 内部的**微动作**时长。它们单独命名而不是散在 build 里，
/// 是因为：这些数一旦各处写一份，微调时必然只改一处，全站就会出现"按钮快
/// 60ms、开关快 80ms"这种说不清的不齐。跨页面的通用档位（[AppMotion.quick]、
/// [AppMotion.commit]、[AppMotion.spring]）仍然只放在 theme/motion.dart。
abstract final class KitMotion {
  /// 松手回弹：按下 1px → 越过 -0.5px → 停回 0，全程 60ms。
  ///
  /// 只有 60ms：回弹是"手已经抬起来、按钮追上来的那一小段"。再长就会被看成
  /// "按钮自己动了一下"，而不是"我刚才按过它"。
  static const release = Duration(milliseconds: 60);

  /// 输入框聚焦：环从 0 长到 3px，边框从 60% 提到 100%。
  static const focus = Duration(milliseconds: 120);

  /// 分段"点亮"（底色出现，不是搬家）。比滑块快一档，因为它只是亮起来。
  static const pick = Duration(milliseconds: 120);

  /// 滑块从一个格子搬到另一个格子；曲线配 [AppMotion.springCurve]。
  static const slide = AppMotion.spring;

  /// 开关切换时轨道横向鼓起 1.5% 再收回。
  static const toggle = Duration(milliseconds: 160);

  /// 骨架屏**首次**出现的淡入（之后整块静止，不循环、不呼吸）。
  static const skeletonIn = Duration(milliseconds: 400);

  /// 角标数字变化时滚到新值（只滚这一次）。
  static const roll = Duration(milliseconds: 200);

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
///
/// 按压反馈交给 [KitPress]（同一个 1px + 60ms 回弹），这样按钮、卡片、列表行
/// 的"按下去"是全站同一种手感，而不是各自 InkWell 一下。
class KitButton extends StatelessWidget {
  const KitButton({
    super.key,
    required this.onTap,
    this.label,
    this.icon,
    this.variant = KitButtonVariant.standard,
    this.size = KitButtonSize.md,
    this.enabled = true,
    this.haptic = false,
  });

  final VoidCallback? onTap;
  final String? label;
  final IconData? icon;
  final KitButtonVariant variant;
  final KitButtonSize size;
  final bool enabled;

  /// 点下去给一次**提交类**触感（[Haptics.commit]，mediumImpact）。
  ///
  /// 默认关，而且只给真正的提交点开：保存、发送、确认、删除确认。普通按钮
  /// （取消、返回、筛选、「再来一次」）开这个会让整屏都在震，触感就不再是信号。
  final bool haptic;

  double get _height => switch (size) {
    KitButtonSize.xs => Kit.hXs,
    KitButtonSize.sm || KitButtonSize.iconSm => Kit.hSm,
    KitButtonSize.lg || KitButtonSize.iconLg => Kit.hLg,
    _ => Kit.hMd,
  };

  bool get _iconOnly => label == null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, border) = switch (variant) {
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
          if (icon case final icon?) Icon(icon, size: size == KitButtonSize.xs ? 12 : 16, color: foreground),
          if (label case final label?) ...[
            if (icon != null) const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: variant == KitButtonVariant.field ? Kit.textControl : Kit.textBody,
                  fontWeight: FontWeight.w500,
                  // 行高 1.35 是中文的底线：1.2 在 14 号上只差 2px，但两行按钮
                  // （或放大字号后）会明显挤在一起。按钮高固定 32，不撑开布局。
                  height: 1.35,
                  color: foreground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: enabled
              ? (_) {
                  if (haptic) Haptics.commit();
                  onTap?.call();
                }
              : null,
          // 只给反馈，不自带点击：点击仍由上面这层 GestureDetector 负责，
          // KitPress 只听裸指针，不参与手势竞争。
          child: KitPress(enabled: enabled, child: content),
        ),
      ),
    );
  }
}

/// 统一的按下反馈：按下整体下移 1px，松手 60ms 回弹（越过停点 0.5px）。
///
/// 为什么抽出来：按下这 1px 是整套界面"有实体"的全部来源，而它之前只长在
/// [KitButton] 里——别的页面用 InkWell 的水波代替，同一屏就出现两种"按下去"。
/// 抽出来之后，卡片、列表行、自绘胶囊都能拿到同一种。
///
/// 两种用法：
/// - **自带点击**：传 [onTap] / [onLongPress]，它会加上按钮语义
///   （[semanticLabel]）和可选的 [haptic]。
/// - **只给反馈**：两个都留空，包一个自己处理点击的子树（[KitButton] 就是这么
///   用的）。这时它只监听裸指针，不进手势竞争；手指移出触摸阈值（在滚动）就撤销。
///
/// 系统"移除动画"时只剩静止的按下状态，没有回弹。
class KitPress extends StatefulWidget {
  const KitPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.haptic = false,
    this.semanticLabel,
    this.offset = Kit.pressOffset,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// false：不变形、不响应（子树照常绘制）。
  final bool enabled;

  /// 只在自带点击时生效：点下去给一次选择类触感（[Haptics.selection]）。
  ///
  /// 它是"选择"不是"提交"——提交类的那一声留给真正落定的动作，用
  /// [Haptics.commit] 在调用的地方自己喊。
  final bool haptic;

  /// 自带点击时用来读的文案；传了就代替子树里的文字（不重复朗读）。
  final String? semanticLabel;

  /// 按下下移的距离（默认 1px）。大卡片可以传 2 让分量更足。
  final double offset;

  /// 只给反馈时的命中范围。
  final HitTestBehavior behavior;

  @override
  State<KitPress> createState() => _KitPressState();
}

class _KitPressState extends State<KitPress> with SingleTickerProviderStateMixin {
  /// 0 = 刚松手，1 = 停稳。静止时停在 1（此时位移为 0）。
  late final AnimationController _lift = AnimationController(vsync: this, duration: KitMotion.release, value: 1);

  bool _down = false;
  Offset? _downAt;

  bool get _ownsTap => widget.onTap != null || widget.onLongPress != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 闸门就在这里：系统关动画时时长是 0，回弹一步到位、没有中间帧。
    _lift.duration = KitMotion.of(context, KitMotion.release);
  }

  @override
  void didUpdateWidget(KitPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 按下途中被禁用（提交后按钮自己变灰是最常见的一种）：立刻抬起来，
    // 别在屏幕上留一个"按着"的按钮。这里直接改字段、不走 setState ——
    // 此刻本来就要重建，再排一次重建是多余的。
    if (oldWidget.enabled && !widget.enabled && _down) {
      _down = false;
      _lift.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _lift.dispose();
    super.dispose();
  }

  /// 当前位移。按下是**立刻**到位的（真按钮不会"慢慢沉下去"），回弹才有动画。
  double get _dy {
    if (_down) return widget.offset;
    final t = AppMotion.swift.transform(_lift.value);
    if (t >= 1) return 0;
    // 显式关键帧：1 → -0.5（越过停点）→ 0。前 40% 用来过冲，后 60% 落回。
    const peak = -Kit.pressRebound;
    if (t <= 0.4) return widget.offset * (1 + (peak - 1) * (t / 0.4));
    return widget.offset * peak * (1 - (t - 0.4) / 0.6);
  }

  void _press() {
    if (!widget.enabled) return;
    _lift.stop();
    if (!_down) setState(() => _down = true);
  }

  void _release() {
    _downAt = null;
    if (!_down) return;
    setState(() => _down = false);
    _lift.forward(from: 0);
  }

  /// 手指在滚动：撤销按下状态，否则滚完列表会留下一个"按着"的按钮。
  void _move(PointerMoveEvent event) {
    final at = _downAt;
    if (at == null) return;
    final slop = MediaQuery.maybeGestureSettingsOf(context)?.touchSlop ?? kTouchSlop;
    if ((event.position - at).distance > slop) _release();
  }

  /// 真正的点击（含读屏点按）：触感只在这里发一次，`onTapUp` 不发——
  /// 一次点击会按顺序走 `onTapUp` 和 `onTap`，两处都发就是震两下。
  void _tap() {
    if (widget.haptic) Haptics.selection();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedBuilder(
      animation: _lift,
      builder: (context, child) => Transform.translate(offset: Offset(0, _dy), child: child),
      child: widget.child,
    );
    if (!_ownsTap) {
      return Listener(
        behavior: widget.behavior,
        onPointerDown: (event) {
          if (!widget.enabled) return;
          _downAt = event.position;
          _press();
        },
        onPointerMove: _move,
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: child,
      );
    }
    final enabled = widget.enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      // 给了文案就用它代替子树文字，免得读屏把同一句话念两遍。
      excludeSemantics: widget.semanticLabel != null,
      onTap: enabled && widget.onTap != null ? _tap : null,
      onLongPress: enabled ? widget.onLongPress : null,
      child: GestureDetector(
        behavior: widget.behavior,
        excludeFromSemantics: true,
        onTapDown: enabled ? (_) => _press() : null,
        onTapUp: enabled ? (_) => _release() : null,
        onTapCancel: enabled ? () => _release() : null,
        onTap: enabled && widget.onTap != null ? _tap : null,
        onLongPress: enabled && widget.onLongPress != null
            ? () {
                _release();
                widget.onLongPress!();
              }
            : null,
        child: child,
      ),
    );
  }
}

/// 开关：18.4 × 32，滑块 16，开着填主色；命中区比可见范围大一圈。
class KitSwitch extends StatefulWidget {
  const KitSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.small = false,
    this.haptic = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool small;

  /// 切换时给一次**选择类**触感（[Haptics.selection]）。
  ///
  /// 默认关：设置页一屏有十几个开关，每个都震就成了噪音。只给"真的改变行为"
  /// 的那些开（比如省电模式、手机操控）。
  final bool haptic;

  /// 命中区在轨道外各留的距离（`after:-inset-x-3 -inset-y-2`）。
  ///
  /// 这一段是**布局**的一部分，不是看不见的手势区：把开关放进行里时，行的
  /// 右内边距要减掉 [hitPadX]，轨道才会和右侧的值、箭头停在同一竖线上
  /// （M3 开关的轨道只在盒子里内缩 4，换成这个开关后原来那 4 就不成立了）。
  static const hitPadX = 12.0;
  static const hitPadY = 8.0;

  @override
  State<KitSwitch> createState() => _KitSwitchState();
}

class _KitSwitchState extends State<KitSwitch> with SingleTickerProviderStateMixin {
  /// 0 → 1 走完就是"鼓起再收回"。静止停在 1（鼓起量为 0）。
  late final AnimationController _bulge = AnimationController(
    vsync: this,
    duration: KitMotion.toggle,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bulge.duration = KitMotion.of(context, KitMotion.toggle);
  }

  @override
  void dispose() {
    _bulge.dispose();
    super.dispose();
  }

  void _toggle() {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    if (widget.haptic) Haptics.selection();
    // 轨道先横向鼓起 1.5% 再收回（160ms）：切换是个"咔哒"的机械动作，
    // 只换颜色的话，轨道读起来像一张会变色的贴纸，而不是一个被拨过去的零件。
    _bulge.forward(from: 0);
    onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = widget.small ? Kit.switchSmW : Kit.switchW;
    final h = widget.small ? Kit.switchSmH : Kit.switchH;
    final thumb = h - 2;
    return Semantics(
      toggled: widget.value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onChanged == null ? null : _toggle,
        child: Padding(
          // after:-inset-x-3 -inset-y-2 → 左右各外扩 12、上下各 8 的命中区。
          padding: const EdgeInsets.symmetric(
            horizontal: KitSwitch.hitPadX,
            vertical: KitSwitch.hitPadY,
          ),
          // 鼓起用 Transform：只动绘制，不动布局——开关在行里占的宽度不变，
          // 右边那列的值、箭头不会跟着抖一下。
          child: AnimatedBuilder(
            animation: _bulge,
            builder: (context, child) {
              final bulge = math.sin(math.pi * _bulge.value.clamp(0.0, 1.0)) * Kit.toggleBulge;
              return Transform.scale(scaleX: 1 + bulge, scaleY: 1, child: child);
            },
            child: AnimatedContainer(
              duration: KitMotion.of(context),
              curve: AppMotion.swift,
              width: w,
              height: h,
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: widget.value ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(h / 2),
              ),
              child: AnimatedAlign(
                duration: KitMotion.of(context),
                curve: AppMotion.swift,
                alignment: widget.value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                child: Container(
                  width: thumb,
                  height: thumb,
                  decoration: BoxDecoration(
                    color: widget.value ? scheme.onPrimary : scheme.surface,
                    shape: BoxShape.circle,
                  ),
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
      duration: KitMotion.of(context, KitMotion.focus),
      curve: AppMotion.swift,
      height: Kit.hMd,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Kit.radiusControl),
        border: Border.all(
          // 聚焦时边框从 60% 提到 100%：环是"外面那圈光"，边框是"自己被点亮"，
          // 两者一起收进来，眼睛读到的才是"这个格子活了"，而不是"多了个影子"。
          color: focused
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        // 环的展开靠颜色从 0 插值到 30%（spread/blur 一直是 3/3，120ms）。
        //
        // 未聚焦时**必须**给一个 alpha 0 的同形状影子，不能给 null：
        // AnimatedContainer 走 `Decoration.lerp` → `BoxShadow.lerpList`，
        // 而后者要求两个列表等长（null 会被当成空列表，一聚焦就抛断言）。
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: focused ? 0.30 : 0),
            spreadRadius: Kit.focusRing / 2,
            blurRadius: Kit.focusRing,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      child: TextField(
        controller: widget.controller,
        focusNode: _node,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: Kit.textBody, height: 1.35),
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
///
/// 数字角标（未读数、条数）从 3 变到 4 时，新数字从下方滚上来 200ms（只滚这一次）。
/// 只在两边**都是纯数字**时才滚：文字换掉（「草稿」→「已发布」）滚起来像坏了；
/// 而数字变化是"同一件事在变"，滚一下能让眼睛在不盯着它的地方也知道它变了。
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
          _ChipLabel(
            label: label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1.35, color: tint),
          ),
        ],
      ),
    );
  }
}

/// 角标文字：数字变化时滚一次，其余情况是普通 [Text]。
class _ChipLabel extends StatefulWidget {
  const _ChipLabel({required this.label, required this.style});

  final String label;
  final TextStyle style;

  @override
  State<_ChipLabel> createState() => _ChipLabelState();
}

class _ChipLabelState extends State<_ChipLabel> {
  /// 上一次变化的两边是不是都是纯数字。初值按当前文案算，所以第一次出现不滚。
  late bool _roll = _isNumber(widget.label);

  static bool _isNumber(String text) {
    if (text.isEmpty) return false;
    for (final unit in text.codeUnits) {
      if (unit < 0x30 || unit > 0x39) return false; // 只认 0-9
    }
    return true;
  }

  @override
  void didUpdateWidget(_ChipLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label == widget.label) return;
    _roll = _isNumber(oldWidget.label) && _isNumber(widget.label);
  }

  @override
  Widget build(BuildContext context) {
    if (!_roll) return Text(widget.label, style: widget.style);
    // ClipRect：滚动的中间帧里新数字会短暂越出 20 高的胶囊，不裁就会画到旁边的
    // 文字上。只有数字角标有这个裁剪，普通文字角标不受影响。
    return ClipRect(
      child: AnimatedSwitcher(
        duration: KitMotion.of(context, KitMotion.roll),
        switchInCurve: AppMotion.swift,
        switchOutCurve: AppMotion.swift,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            // 从下方 45% 处升上来：位移很小，读起来是"换了一位数字"，不是"换了个角标"。
            position: Tween(begin: const Offset(0, 0.45), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: Text(widget.label, key: ValueKey(widget.label), style: widget.style),
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
            duration: KitMotion.of(context, KitMotion.pick),
            curve: AppMotion.swift,
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
/// `cubic-bezier(0.34, 1.24, 0.64, 1)`（= [AppMotion.springCurve]）——带一点回弹，
/// 手感比 linear 活。滑块在途中还会被横向压 4%（scaleX 0.96）：真零件被推着走时
/// 前后会被挤一下，少了这一下，滑块就只是"一个矩形平移了"。
class KitDualToggle extends StatefulWidget {
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
  static const curve = AppMotion.springCurve;

  @override
  State<KitDualToggle> createState() => _KitDualToggleState();
}

class _KitDualToggleState extends State<KitDualToggle> with SingleTickerProviderStateMixin {
  /// 0 → 1 与滑块搬家同步；途中压缩量按 sin(π·t) 取得，静止时正好为 0。
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: KitMotion.slide,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slide.duration = KitMotion.of(context, KitMotion.slide);
  }

  @override
  void didUpdateWidget(KitDualToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rightSelected != widget.rightSelected) _slide.forward(from: 0);
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

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
              duration: KitMotion.of(context, KitMotion.slide),
              curve: KitDualToggle.curve,
              alignment: widget.rightSelected ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  // 压缩只作用在滑块自己身上（不含那 3px 内缩），否则途中会连
                  // 滑块和轨道之间的缝一起缩，看起来像整块在呼吸。
                  child: AnimatedBuilder(
                    animation: _slide,
                    builder: (context, child) {
                      final squeeze = math.sin(math.pi * _slide.value.clamp(0.0, 1.0)) * Kit.slideSqueeze;
                      return Transform.scale(scaleX: 1 - squeeze, child: child);
                    },
                    // SizedBox.expand 是必须的：DecoratedBox 没有子节点时会取约束的
                    // 最小值，而 AnimatedAlign 给的是松约束 —— 少了它滑块的高度是 0，
                    // 这个控件就只剩轨道和文字（改之前就是这样）。
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: knob, borderRadius: BorderRadius.circular(999)),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: _Half(item: widget.left, selected: !widget.rightSelected, onTap: () => widget.onChanged(false)),
                  ),
                  Expanded(
                    child: _Half(item: widget.right, selected: widget.rightSelected, onTap: () => widget.onChanged(true)),
                  ),
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
