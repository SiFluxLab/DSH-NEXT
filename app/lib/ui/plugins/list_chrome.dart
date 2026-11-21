// 列表页共用的四件小事：骨架屏、计数器滚动、按住抬升、标签行末尾渐隐，
// 外加空态按钮的一次呼吸和下拉刷新时页顶那条光带。
//
// 为什么放在 ui/plugins/：插件市场 + 已安装 + 插件清单是这批页面里列表最多的
// 一处，而工坊本来就依赖这个目录（`workshop_widgets.dart` 取 `PluginAvatar`），
// 所以放这里不会新造一个"谁都不属于"的角落；酒馆与文件页按同一份实现取用。
//
// 这一层只管**列表的形状与它自己的动作**：占位条、数字怎么滚、按住时抬多高、
// 标签行怎么收尾。字号、颜色、圆角、缓动一律仍然来自 kit/ 与 theme/——
// 这里不新增任何颜色、字号或时长常量，否则四个页面很快会各飘一档。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../kit/kit.dart';
import '../kit/kit_list.dart' show KitRow;
import '../theme/spectral.dart';
import '../theme/theme.dart';

/// 卡片标题 13.5/600。四类列表页共用这一档：比列表行的 14/500 小半档、
/// 重一档——同一屏里"卡"和"行"混排时，这一档差别刚好分得清主次。
TextStyle cardTitleStyle(ThemeData theme) => TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w600,
  height: 1.4,
  color: theme.colorScheme.onSurface,
);

/// 卡片说明 12/70%：规格 §7.8 的二级文字档，用透明度而不是另一个灰阶。
TextStyle cardNoteStyle(BuildContext context) =>
    TextStyle(fontSize: 12, height: 1.4, color: DshColors.of(context).textTertiary.withValues(alpha: KitMuted.a70));

/// 卡片元信息 11/60%：卡里最小的一层，只回答"哪个版本、多大、什么时候"。
/// 数字用等宽数字，值变化（滚动计数）时宽度不抖。
TextStyle cardMetaStyle(BuildContext context) => AppType.tabular(
  // 行高 1.35 是中文的底线：11 号上 1.3 只差 0.5px，但说明里带汉字（「1.0.0 · 已撤回」）
  // 时就会显挤。
  TextStyle(fontSize: 11, height: 1.35, color: DshColors.of(context).textTertiary.withValues(alpha: KitMuted.a60)),
);

/// 首屏骨架：几张与真卡同尺寸的占位卡，条块是**静态微光**，不循环。
///
/// 为什么不留一个转圈：转圈只说明"在等"，骨架说明"等来的是什么"——加载前后
/// 版面不跳位置，列表到位时是"填满"，不是"换掉"。
///
/// 为什么不做扫过去的高光：列表首读常常要两三秒，一道亮光会一直在视野边缘动，
/// 读起来像故障。条块用 kit 的 [KitSkeletonBar]（静态的上下渐变），有"还没干的
/// 面"的质感，但一帧都不会再动。
///
/// 这一版只给"一条记录一张卡"的列表用（工坊、插件市场）；设置行那种分组卡里的
/// 一行行，直接用 kit 的 [KitSkeleton]——那边的行高、内距已经和 `KitRow` 对齐。
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    this.rows = 6,
    this.avatar = 40,
    this.lines = 2,
    this.trailing = 68,
    this.label,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 16),
  });

  /// 首屏画几张。6 张刚好铺满一屏多一点，滑动时不会立刻见底。
  final int rows;

  /// 方块边长；0 表示这页没有方块（纯文字行）。
  final double avatar;

  /// 说明行数：2 = 标题 + 一行说明；3 = 标题 + 两行说明。
  final int lines;

  /// 右缘控件（获取 / 开关）的占位宽；0 表示没有。
  final double trailing;

  /// 读屏用的整块说明（"正在加载"）。不给就整块对读屏不可见——
  /// 占位条没有文字，报出一堆空节点只会让人以为页面坏了。
  final String? label;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 每一条占位都用 kit 的 [KitSkeletonBar]：静态微光（上亮下暗）来自那一处，
    // 四个列表页的骨架因此是同一种"纸面受光"，而不是各调一个灰。
    Widget line(double width, double height) => KitSkeletonBar(width: width, height: height);
    Widget row(int i) {
      // 每条卡的说明长短不一：奇数条短一点，一眼看去是"不同的条目"，
      // 而不是复读机。用宽度比例，不掺任何假文字假数字。
      final note = i.isEven ? 0.62 : 0.44;
      final content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avatar > 0) ...[
            KitSkeletonBar(width: avatar, height: avatar, radius: avatar * 0.25),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(double.infinity, 12),
                for (var l = 1; l < lines; l++) ...[
                  const SizedBox(height: 8),
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: l == 1 ? 1 : note,
                    child: line(double.infinity, 10),
                  ),
                ],
                if (lines > 1) ...[
                  const SizedBox(height: 10),
                  // 标签行的位置：一枚胶囊宽的条。它不代表任何数字或文字，
                  // 只说"这里会有一排标签"。
                  const SizedBox(width: 96, child: KitSkeletonBar(height: 14)),
                ],
              ],
            ),
          ),
          if (trailing > 0) ...[
            const SizedBox(width: 12),
            KitSkeletonBar(width: trailing, height: 28, radius: 8),
          ],
        ],
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Kit.radiusPanel),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(padding: KitRow.contentPadding, child: content),
        ),
      );
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [for (var i = 0; i < rows; i++) row(i)],
    );
    return Padding(
      padding: padding,
      child: RepaintBoundary(
        child: label == null ? column : Semantics(label: label, container: true, child: column),
      ),
    );
  }
}

/// 分组计数：值变化时在 200ms 内滚到新值，**只滚一次**。
///
/// 为什么值得写这一层：计数是列表里唯一会"没被请求就变了"的东西（后台装好一个、
/// 拉回一条）。直接换字会让人怀疑自己看错；滚一下就把"它变了"说清楚了。
/// 只在值真的变了才动画——值不变时这里一个补间都不建，滚动时零成本。
class RollingCount extends StatefulWidget {
  const RollingCount(this.value, {super.key, this.style, this.format});

  final int value;
  final TextStyle? style;

  /// 数字怎么写（「12 项」「12 个插件」）。留空就只写数字。
  ///
  /// 用回调而不是拼一个后缀：中文量词与英文单复数是两句话，拼出来一定会偏袒
  /// 其中一种语言。
  final String Function(int value)? format;

  @override
  State<RollingCount> createState() => _RollingCountState();
}

class _RollingCountState extends State<RollingCount> {
  /// 这次补间的起点：上一次画出来的整数。初次构建就等于当前值，所以首帧不滚。
  late double _from = widget.value.toDouble();

  @override
  void didUpdateWidget(RollingCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _from = oldWidget.value.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style =
        widget.style ??
        TextStyle(fontSize: 12, height: 1.35, color: scheme.onSurfaceVariant.withValues(alpha: KitMuted.a60));
    // 闭包在这里建一次，不进每帧的 builder：动画期间每帧只做一次插值与组字。
    final format = widget.format ?? (int value) => '$value';
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _from, end: widget.value.toDouble()),
      duration: KitMotion.of(context, KitMotion.roll),
      curve: AppMotion.std,
      builder: (context, value, _) => Text(format(value.round()), style: AppType.tabular(style)),
    );
  }
}

/// 按住抬升：手指停住 240ms 后整张卡上移 2px、影子加深，松手回到原处。
///
/// 只挂在**卡片**上（一条记录一张卡的那种），不挂在分组卡里的行：行被按住时
/// 抬起来会把上下两条行缝一起带歪，反而像掉帧。
///
/// 用 [Listener] 而不是 GestureDetector：Listener 不进手势竞技场，卡片自己的
/// 点击、长按菜单照旧生效；手指一动超过 12px 就当作"在滚列表"立刻放下。
class PressLift extends StatefulWidget {
  const PressLift({super.key, required this.child, this.radius = Kit.radiusPanel, this.lift = 2, this.enabled = true});

  final Widget child;
  final double radius;

  /// 抬起的距离。2px 是"拿起一张纸"，再多就像拖拽了。
  final double lift;

  /// 关闭时不响应（多选状态、不可点的卡）。
  final bool enabled;

  @override
  State<PressLift> createState() => _PressLiftState();
}

class _PressLiftState extends State<PressLift> {
  Timer? _hold;
  Offset? _origin;
  bool _lifted = false;

  /// 系统长按阈值是 500ms；这里 240ms 就抬，是"手刚停住它就起来"，
  /// 而不是"等菜单出现才动"。抬升本身 120ms，落在 ≤120ms 的反馈档里。
  static const _holdDelay = Duration(milliseconds: 240);
  static const _travel = Duration(milliseconds: 120);

  static const _shadow = [
    BoxShadow(color: Color(0x24000000), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -6),
    BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2), spreadRadius: -2),
  ];

  void _down(PointerDownEvent event) {
    if (!widget.enabled) return;
    _origin = event.position;
    _hold?.cancel();
    _hold = Timer(_holdDelay, () {
      if (mounted) setState(() => _lifted = true);
    });
  }

  void _move(PointerMoveEvent event) {
    final origin = _origin;
    if (origin == null) return;
    if ((event.position - origin).distance > 12) _release();
  }

  void _release() {
    _hold?.cancel();
    _hold = null;
    _origin = null;
    if (_lifted && mounted) setState(() => _lifted = false);
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: RepaintBoundary(
        child: AnimatedContainer(
          duration: KitMotion.of(context, _travel),
          curve: AppMotion.std,
          transform: Matrix4.translationValues(0, _lifted ? -widget.lift : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            // 抬起来要"离桌面远一点"：影子变大变淡，卡本身不动高度，
            // 所以列表不会因为这 2px 重新排版。
            boxShadow: _lifted ? _shadow : const <BoxShadow>[],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 标签行：一行 [KitChip]，放不下时**末尾渐隐**进卡面，而不是被硬边切掉。
///
/// 怎么做到不量宽度：右端常驻一条 24px 的"从卡面到透明"的渐变。标签没排到那个
/// 位置时，渐变底下什么都没有，画面完全不变；排到了，最后一枚就是淡出去的。
/// 这样不用 LayoutBuilder、不用测量、也不用手势——横滑仍然是外面列表的。
class ChipRowFade extends StatelessWidget {
  const ChipRowFade({super.key, required this.chips, this.height = 20, this.gap = 6, this.fade = 24, this.surface});

  final List<Widget> chips;
  final double height;
  final double gap;

  /// 渐隐带宽度。24 约等于一枚 chip 的圆角端头，短到只吃掉"半枚"。
  final double fade;

  /// 卡面颜色；默认按内容卡的 `surfaceContainerLow`，与 [KitCard] 同一档。
  final Color? surface;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    final face = surface ?? Theme.of(context).colorScheme.surfaceContainerLow;
    // 宽度撑满可用空间：否则 Stack 会缩到"标签刚好那么宽"，右端那条渐变就
    // 永远盖在最后一枚标签上——放得下也被洗掉一半。
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          // 永不接手的横向滚动：只为让超出的部分被裁掉而不报 overflow。
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, chip) in chips.indexed) ...[
                  if (i > 0) SizedBox(width: gap),
                  chip,
                ],
              ],
            ),
          ),
          PositionedDirectional(
            start: null,
            end: 0,
            top: 0,
            bottom: 0,
            width: fade,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: [face.withValues(alpha: 0), face],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 空态的动作按钮：页面停留 3s 后做**一次** 600ms 的柔和呼吸（1 → 1.03 → 1）。
///
/// 为什么只做一次：空态是"没什么可做"的画面，按钮需要被注意到；但重复呼吸就是
/// 常驻动画——耗电，还会让人以为有什么东西在等。注意到之后，它就一直安静待着。
/// 系统开了"移除动画"时，这一步连计时器都不建。
class BreatheOnce extends StatefulWidget {
  const BreatheOnce({
    super.key,
    required this.child,
    this.delay = const Duration(seconds: 3),
    this.duration = const Duration(milliseconds: 600),
    this.scale = 1.03,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// 呼吸的最大放大。3% 在 44 高的按钮上约 1.3px——看得见"动了一下"，
  /// 但不会像在招手。
  final double scale;

  @override
  State<BreatheOnce> createState() => _BreatheOnceState();
}

class _BreatheOnceState extends State<BreatheOnce> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: widget.duration);
  Timer? _timer;
  bool _planned = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_planned) return;
    _planned = true;
    if (AppMotion.reduced(context)) return;
    _timer = Timer(widget.delay, () {
      // 3s 之内就离开这一页的人，不该为此付一次构建。
      if (mounted) unawaited(_breath.forward());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breath,
      child: widget.child,
      builder: (context, child) => Transform.scale(
        // sin 一趟：0 → 1 → 0，两端的导数为 0，起落都不"跳"。
        scale: 1 + (widget.scale - 1) * math.sin(_breath.value * math.pi),
        child: child,
      ),
    );
  }
}

/// 下拉刷新时页顶的光带：一条 1.5px 的细线，刷新开始就上移 8px 并亮起来。
///
/// 颜色直接用输入框流光那一套光谱（[Spectral.ramp]）——它已经是这个 App 里
/// "光"唯一的写法，换一套渐变会让页顶看起来像另一个产品。
///
/// 位置用 top 而不是 transform：整条只有一个盒子在动，动完就停；容器高度固定
/// （8 + 线宽），所以它上升不会挤动下面的内容——静止时线贴在这一格的底边，
/// 刷新时顶到上沿，正好走完 8px。
class PullLightBand extends StatelessWidget {
  const PullLightBand({super.key, required this.active, this.height = 8, this.inset = 16});

  final bool active;
  final double height;

  /// 左右留白，与页面的 16 列对齐。
  final double inset;

  @override
  Widget build(BuildContext context) {
    final duration = KitMotion.of(context, AppMotion.emphasized);
    // 线宽 1.5；这一格的高度要多出这 1.5，静止时线才落在格子的底边而不是被裁掉。
    const thickness = 1.5;
    return ExcludeSemantics(
      child: SizedBox(
        height: height + thickness,
        child: ClipRect(
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: AppMotion.std,
                left: inset,
                right: inset,
                height: thickness,
                // 静止在下沿、刷新在上沿：位移正好是 height（8px），
                // 也就是"整条光带往上让了一格"。
                top: active ? 0 : height,
                child: AnimatedOpacity(
                  duration: duration,
                  opacity: active ? 1 : 0.45,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(thickness / 2),
                      gradient: LinearGradient(
                        colors: [
                          Spectral.at(0).withValues(alpha: 0.0),
                          Spectral.ramp[1],
                          Spectral.ramp[2],
                          Spectral.ramp[3],
                          Spectral.ramp[3].withValues(alpha: 0.0),
                        ],
                        stops: const [0, 0.28, 0.55, 0.8, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 空态唯一那个动作：与 [EmptyView] 自带的按钮同一副样子（44 高、左右 20、
/// 描边），但外面包了一层 [BreatheOnce]。
///
/// 为什么这里要把那几行 ButtonStyle 写一遍：[EmptyView] 只接受 `actionLabel`
/// 或一个现成的 `action`，而"只让按钮呼吸、不让整块空态跟着放大"必须拿到按钮
/// 本身。样式与 [EmptyView] 里的 OutlinedButton 逐字一致，改那边时记得改这里。
class EmptyAction extends StatelessWidget {
  const EmptyAction({super.key, required this.label, this.onPressed, this.breathe = true});

  final String label;
  final VoidCallback? onPressed;

  /// 关掉呼吸：同一个空态在很短的面板里（抽屉、卡片）不该再"招手"。
  final bool breathe;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      child: Text(label),
    );
    return breathe ? BreatheOnce(child: button) : button;
  }
}
