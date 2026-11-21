// 抽屉打开时，首屏内容错峰入场。
//
// 只朝"打开"这一个方向播：抽屉从 0 → 打开的那一刻起跑一次，前 8 行依次
// 上移 8dp + 淡入（30ms 一档）；关闭、中途再关、来回拉着看，都不会重播，
// 也不会倒放。系统开了"减少动画"或关掉"预见性动画"时整段不发生——
// 所有项一开始就在位，不会有人看到半透明的一列。
//
// 为什么是"一次 + 只在打开时"：抽屉是每天开几十次的地方，每次都播会很快变成
// 噪音；只在"打开"这一刻给一点层次，它才像"内容跟着抽屉一起到位"，
// 而不是"列表本来就长这样"。

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../kit/kit.dart';
import '../../kit/kit_reveal.dart' show KitReveal;
import '../../theme/theme.dart';

/// 一屏入场的总时长：最后一项的 30ms 偏移 + 一项自己的 240ms。
final _total = AppMotion.stagger * AppMotion.staggerLimit + AppMotion.standard;

/// 包住抽屉内容：监听抽屉的开合，打开时让 [DrawerStagger] 的子项错峰入场。
///
/// [motion] 是被拉出的抽屉自己的 0 → 1 动画（常驻侧栏传 null，就不播）。
class DrawerEntrance extends StatefulWidget {
  const DrawerEntrance({super.key, required this.motion, required this.child});

  final Animation<double>? motion;
  final Widget child;

  @override
  State<DrawerEntrance> createState() => _DrawerEntranceState();
}

class _DrawerEntranceState extends State<DrawerEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(vsync: this, duration: _total, value: 1);

  /// 上一次读到的开合状态（0.02 是"开始推开了"，不是 0 也不算全开）。
  /// 必须在 initState 里就定下来：用 late 惰性求值的话，第一次读到的会是
  /// 已经推开之后的值，那一次打开就不会播（正好播反）。
  late bool _open;

  /// 这次能不能播（减少动画 / 关掉预见性动画时不能）。
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    _open = (widget.motion?.value ?? 0) > 0.02;
    widget.motion?.addListener(_onMotion);
  }

  @override
  void didUpdateWidget(DrawerEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion != widget.motion) {
      oldWidget.motion?.removeListener(_onMotion);
      widget.motion?.addListener(_onMotion);
      _open = (widget.motion?.value ?? 0) > 0.02;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖（无障碍的"移除动画"、光感档位）只在这里读一次，别在手势回调里读。
    _animate = KitMotion.choreography(context);
  }

  void _onMotion() {
    final open = (widget.motion?.value ?? 0) > 0.02;
    if (open && !_open && _animate) _run.forward(from: 0);
    _open = open;
  }

  @override
  void dispose() {
    widget.motion?.removeListener(_onMotion);
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EntranceScope(run: _run, total: _run.duration ?? AppMotion.standard, child: widget.child);
  }
}

/// 把"这次入场跑到哪了"传给下面每一个 [DrawerStagger]。
class _EntranceScope extends InheritedWidget {
  const _EntranceScope({required this.run, required this.total, required super.child});

  final Animation<double> run;

  /// 整段入场时长。Animation 本身没有 duration（只有 AnimationController 有），
  /// 之前写 `run.duration` 直接编译不过；把值随 scope 带下来最省事也最准确。
  final Duration total;

  @override
  bool updateShouldNotify(_EntranceScope oldWidget) => run != oldWidget.run;
}

/// 一个参与入场错峰的项：按 [index] 排 30ms 一档。
///
/// 只做画上去的那一层（透明度 + 位移），**不动布局**：入场期间列表的行高、
/// 滚动位置、点击命中区都还是最终的样子。
class DrawerStagger extends StatelessWidget {
  const DrawerStagger({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  /// 一项自己走完这段的比例（240 / 480）。
  static const _span = 0.5;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_EntranceScope>();
    final run = scope?.run;
    // 第 9 项往后直接给出来：错峰超过 8 项就成了"半个列表还没出现"，
    // 那时人已经在看内容了，不需要再慢慢浮出来。
    if (run == null || scope == null || index >= AppMotion.staggerLimit) return child;
    final step = AppMotion.stagger.inMicroseconds / math.max(1, scope.total.inMicroseconds);
    final start = (index * step).clamp(0.0, 1.0 - _span);
    return AnimatedBuilder(
      animation: run,
      builder: (context, child) {
        final t = Interval(start, math.min(1.0, start + _span), curve: AppMotion.swift).transform(run.value);
        if (t >= 1) return child!;
        return Opacity(
          opacity: t,
          alwaysIncludeSemantics: true,
          // 6px（[KitReveal.rise]）：和全站区块入场同一个上浮距离，不出现 6/8 参差。
          child: Transform.translate(offset: Offset(0, KitReveal.rise * (1 - t)), child: child),
        );
      },
      child: child,
    );
  }
}
