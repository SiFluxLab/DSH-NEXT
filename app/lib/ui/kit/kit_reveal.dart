import 'package:flutter/widgets.dart';

import '../theme/motion.dart';
import 'kit.dart';

/// 入场编排：淡入 + 从下方 6px 浮上来，**只播一次**，受 [KitMotion.choreography] 控制。
///
/// 和 `common/fade_in.dart` 的 `FadeSlideIn` 分工：`FadeSlideIn` 管"列表第一次
/// 出现，前 8 项各错开 30ms"，还带"滚进视野的项不再重播"那套节流；这里是
/// "单个区块进场"，一次、一小段、不排队。两块页面级内容同屏时各用各的，
/// 不要混着用——混用会出现"第一块浮 6px、第二块浮 8px"的参差。
///
/// 为什么是 6px 而不是 12px：超过 8px 人就会注意到"它在动"（注意力被动画本身
/// 抢走）；6px 只让人觉得"它本来就在那儿"。为什么走 [AppMotion.spring]：
/// 250–400ms 的到位段，末尾收得干脆，不会拖出等待感。
///
/// 关闭"预见性动画"（`Optics.anticipation`，省电档也会关）或系统要求减少
/// 动画时，它**直接**返回子树：不淡入、不位移、不留任何包装层。
///
/// ```dart
/// KitReveal(delay: AppMotion.stagger * 2, child: KitCard(child: ...))
/// ```
class KitReveal extends StatefulWidget {
  const KitReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.spring,
    this.offset = rise,
  });

  final Widget child;

  /// 推迟多久开始（多个区块要错峰时传 `AppMotion.stagger * index`）。
  final Duration delay;

  /// 到位时长；默认 [AppMotion.spring]（300ms）。
  final Duration duration;

  /// 上浮距离，默认 [rise]（6px）。
  final double offset;

  /// 6px：看得出"浮上来"，但不会让人意识到有一个动画在跑。
  static const rise = 6.0;

  @override
  State<KitReveal> createState() => _KitRevealState();
}

class _KitRevealState extends State<KitReveal> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  CurvedAnimation? _curve;

  /// 只在第一次挂载时决定一次：之后的重建（父级 setState、主题变化）都不再播。
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    // 编排档关掉时直接呈现：省一帧动画，也符合"我只要结果"的选择。
    if (!KitMotion.choreography(context)) return;
    final motion = KitMotion.of(context, widget.duration);
    final total = widget.delay + motion;
    if (total == Duration.zero) return;
    final controller = AnimationController(vsync: this, duration: total);
    final start = widget.delay.inMicroseconds / total.inMicroseconds;
    _controller = controller;
    _curve = CurvedAnimation(
      parent: controller,
      curve: Interval(start, 1, curve: AppMotion.swift),
    );
    controller.forward();
  }

  @override
  void dispose() {
    _curve?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final curve = _curve;
    if (controller == null || curve == null) return widget.child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = curve.value;
        return Opacity(
          opacity: t,
          // 淡入期间子树已经在语义树里：读屏和查找不会"等动画放完"。
          alwaysIncludeSemantics: true,
          child: Transform.translate(offset: Offset(0, widget.offset * (1 - t)), child: child),
        );
      },
      child: widget.child,
    );
  }
}
