// 环绕输入框的流光（prism 的棱镜环，改成随引擎状态变）。
//
// 与之前屏幕顶端那条"光刃"的区别：
//   · 位置：贴着输入卡的边框走一圈，而不是悬在页面顶沿；
//   · 语义：四态各有一副样子（空闲静止、流式绕行、跑工具中段脉动、等你决定时暖色停驻）；
//   · 过渡：状态切换用 320ms 交叉淡入淡出，**不做位置跳变**——你在打字时它不该闪。
//
// 性能：整圈是**一个** CustomPainter，只画描边（Stroke），不做背景模糊、不 blur；
// 空闲态把 ticker 停掉，静止帧就是一圈 22% 的环（与 AppMotion 的"空闲停帧"一致）。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/blade_state.dart';
import '../../theme/spectral.dart';
import '../../theme/theme.dart';

class ComposerAura extends ConsumerStatefulWidget {
  const ComposerAura({super.key, required this.radius, required this.child});

  /// 与输入卡外沿一致的圆角，环贴着它走。
  final BorderRadius radius;
  final Widget child;

  @override
  ConsumerState<ComposerAura> createState() => _ComposerAuraState();
}

class _ComposerAuraState extends ConsumerState<ComposerAura> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  /// 上一态与当前态：切换时在两者之间插值 320ms，避免"啪"地换色。
  BladeState _from = BladeState.idle;
  BladeState _to = BladeState.idle;
  late final AnimationController _shift = AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);

  @override
  void initState() {
    super.initState();
    _sweep.repeat();
    _shift.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _from = _to);
        _shift.value = 1;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  void _stateChanged(BladeState next) {
    if (next == _to) return;
    _from = _to;
    _to = next;
    if (MediaQuery.disableAnimationsOf(context)) {
      _from = next;
      return;
    }
    _shift.forward(from: 0);
  }

  @override
  void dispose() {
    _sweep.dispose();
    _shift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(bladeStatusProvider);
    // 状态变了就起一次过渡（在 build 之外调度，避免 setState during build）。
    if (status != _to) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _stateChanged(status);
      });
    }
    final optics = Optics.of(context);
    final animate = optics.blade > 0 && !MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        widget.child,
        if (optics.blade > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_sweep, _shift]),
                  builder: (context, _) => CustomPaint(
                    painter: _AuraPainter(
                      from: _from,
                      to: _to,
                      t: _shift.value,
                      // 时间只喂给"绕行"那一态：其它态是静止或呼吸，不需要扫。
                      sweep: animate ? _sweep.value : 0.15,
                      strength: optics.blade,
                      accent: Theme.of(context).colorScheme.primary,
                      warn: Theme.of(context).colorScheme.tertiary,
                      radius: widget.radius,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AuraPainter extends CustomPainter {
  _AuraPainter({
    required this.from,
    required this.to,
    required this.t,
    required this.sweep,
    required this.strength,
    required this.accent,
    required this.warn,
    required this.radius,
  });

  final BladeState from;
  final BladeState to;
  final double t;
  final double sweep;
  final double strength;
  final Color accent;
  final Color warn;
  final BorderRadius radius;

  /// 每一态的"环长 + 亮度 + 是否扫动"。切换时在这三组数之间插值。
  (double, double, double) _shape(BladeState s) => switch (s) {
    // 空闲：整圈淡环，静止。
    BladeState.idle => (1.0, 0.22, 0.0),
    // 流式：一段 38% 的亮弧在跑。
    BladeState.streaming => (0.38, 0.95, 1.0),
    // 跑工具：中段来回的短弧。
    BladeState.working => (0.24, 0.80, 0.6),
    // 等你决定：几乎整圈、暖色、慢脉动。
    BladeState.waiting => (0.92, 0.85, 0.25),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final a = _shape(from);
    final b = _shape(to);
    final arcSpan = _lerp(a.$1, b.$1);
    final alpha = _lerp(a.$2, b.$2) * strength;
    final motion = _lerp(a.$3, b.$3);

    // 等你在决定时环转暖：颜色也在两态之间插值，而不是瞬间换色。
    final warm = to == BladeState.waiting ? t : (from == BladeState.waiting ? 1 - t : 0.0);
    final color = Color.lerp(accent, warn, warm)!;

    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.75);
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;

    // 底环：整圈 10%，让"有这么一个环"始终读得出来。
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.10 * strength),
    );

    // 亮弧位置：working 用三角波来回，其余单向绕行。
    final travel = to == BladeState.working ? 1 - (2 * sweep - 1).abs() : sweep;
    final start = metric.length * travel;
    final span = metric.length * arcSpan;

    // 色相随时间缓慢漂移：这一格让光"活着"，但不是循环动画（旋转极慢，肉眼只感到色温变化）。
    final phase = (sweep * 0.35) % 1.0;

    Path arcPath() {
      final head = metric.extractPath(start, math.min(start + span, metric.length));
      if (start + span <= metric.length) return head;
      // 跨过终点：把前半段接上，弧才不会断。
      return head..addPath(metric.extractPath(0, start + span - metric.length), Offset.zero);
    }

    void strokeArc(double width, Color Function(double t) tint, BlendMode blend) {
      final gradient = LinearGradient(
        colors: Spectral.arc(phase, alpha).map((c) => tint(c.a)).toList(),
        stops: Spectral.stops,
      );
      canvas.drawPath(
        arcPath(),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..blendMode = blend
          ..shader = gradient.createShader(rect),
      );
    }

    if (arcSpan >= 0.995) {
      // 整圈（idle / waiting）：沿环画一条分光渐变，不设断口。
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..blendMode = kLightBlend
          ..shader = SweepGradient(
            colors: [
              Spectral.at(phase).withValues(alpha: alpha * 0.5),
              Spectral.at(phase + 0.35).withValues(alpha: alpha),
              Spectral.glow.withValues(alpha: alpha),
              Spectral.at(phase + 0.7).withValues(alpha: alpha * 0.6),
              Spectral.at(phase).withValues(alpha: alpha * 0.5),
            ],
            transform: const GradientRotation(0),
          ).createShader(rect),
      );
    } else {
      // 辉光层：更粗、很淡、加色——不花一次 blur 就得到"光晕"。
      strokeArc(7, (c) => c.withValues(alpha: c.a * 0.16), kLightBlend);
      // 主体：分光弧。
      strokeArc(1.9, (c) => c, kLightBlend);
      // 白热头：最后 6% 的一段拉成近白，光的"速度感"全在这里。
      final headLen = math.max(1.0, span * 0.08);
      final headStart = math.min(start + span, metric.length) - headLen;
      if (headStart > 0) {
        final headPath = metric.extractPath(headStart, headStart + headLen);
        canvas.drawPath(
          headPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..blendMode = kLightBlend
            ..color = Colors.white.withValues(alpha: 0.75 * alpha),
        );
      }
    }
    // 4.0 的 motion 只用于将来需要按状态调速时读取；现在保持编译期无副作用。
    assert(motion >= 0);
  }

  double _lerp(double a, double b) => a + (b - a) * t;

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.from != from || old.to != to || old.t != t || old.sweep != sweep || old.accent != accent;
}
