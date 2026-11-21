// 「光刃」：这一版 UI 的签名元素。
//
// 它是玻璃表面上沿的一条极窄高光，只反映引擎真实状态，不做装饰：
//   空闲 → 一个 2.4s 的呼吸；流式 → 从左走到右；工具在跑 → 中段来回；等你决定 → 停在一半并脉动。
//
// 性能约定：整条光刃是一个 CustomPainter，不新建图层、不加 BackdropFilter；
// 光感档位为 silent 或系统开了"移除动画"时整块不绘制（连 ticker 都不建）。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';

class LightBlade extends StatefulWidget {
  const LightBlade({
    super.key,
    required this.state,
    this.radius = 18,
    this.thickness = 1.4,
    this.color,
  });

  final BladeState state;

  /// 与所在表面相同的圆角：光刃贴着上沿走，端点跟着圆角收进去。
  final double radius;
  final double thickness;

  /// 默认取当前强调色；调用方可以给一个更暗的版本（深色底上）。
  final Color? color;

  @override
  State<LightBlade> createState() => _LightBladeState();
}

class _LightBladeState extends State<LightBlade> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppMotion.breath);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LightBlade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _sync();
  }

  void _sync() {
    final optics = Optics.of(context);
    final animate = optics.blade > 0 && !MediaQuery.disableAnimationsOf(context);
    if (!animate) {
      if (_controller.isAnimating) _controller.stop();
      return;
    }
    final duration = switch (widget.state) {
      BladeState.streaming => const Duration(milliseconds: 1400),
      BladeState.working => const Duration(milliseconds: 1800),
      BladeState.waiting => const Duration(milliseconds: 2200),
      BladeState.idle => AppMotion.breath,
    };
    if (_controller.duration != duration) _controller.duration = duration;
    if (!_controller.isAnimating) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final optics = Optics.of(context);
    if (optics.blade <= 0) return const SizedBox.shrink();
    final accent = widget.color ?? Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.thickness,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _BladePainter(
                state: widget.state,
                t: _controller.value,
                strength: optics.blade,
                prism: optics.prism,
                accent: accent,
                radius: widget.radius,
                thickness: widget.thickness,
                animate: _controller.isAnimating,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BladePainter extends CustomPainter {
  _BladePainter({
    required this.state,
    required this.t,
    required this.strength,
    required this.prism,
    required this.accent,
    required this.radius,
    required this.thickness,
    required this.animate,
  });

  final BladeState state;
  final double t;
  final double strength;
  final double prism;
  final Color accent;
  final double radius;
  final double thickness;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    // 端点落在圆角之内，免得光刃戳出玻璃边缘。
    final inset = math.min(radius, size.width / 2);
    final left = inset;
    final right = size.width - inset;
    final span = math.max(0.0, right - left);
    if (span <= 0) return;

    // 光刃本体占整个上沿的三分之一左右，随状态移动。
    final head = math.max(span * 0.34, 24.0);
    final (start, alpha) = switch (state) {
      // 呼吸：整体亮度起伏，位置不动（不位移就不会抢注意力）。
      BladeState.idle => (left, 0.35 + 0.25 * (0.5 - 0.5 * math.cos(t * 2 * math.pi))),
      // 流式：从左走到右，到了就重来。
      BladeState.streaming => (left + (span - head) * t, 0.85),
      // 工具在跑：中段来回，用三角波。
      BladeState.working => (left + (span - head) * (1 - (2 * t - 1).abs()), 0.7),
      // 等你决定：停在一半，慢脉动。
      BladeState.waiting => (left + (span - head) * 0.5, 0.55 + 0.35 * (0.5 - 0.5 * math.cos(t * 2 * math.pi))),
    };

    final rect = Rect.fromLTWH(start, 0, head, thickness);
    final fade = animate ? 1.0 : 0.6;

    // 主体：一段 accent 的渐变，两端透明。
    final body = Paint()
      ..shader = LinearGradient(
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: 0.55 * strength * alpha * fade),
          accent.withValues(alpha: 0.9 * strength * alpha * fade),
          accent.withValues(alpha: 0.55 * strength * alpha * fade),
          accent.withValues(alpha: 0),
        ],
        stops: const [0, 0.18, 0.5, 0.82, 1],
      ).createShader(rect)
      ..blendMode = BlendMode.plus;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(thickness)), body);

    // 棱镜：光刃两端各散出一层很淡的偏色，只在"完整光感"里出现。
    if (prism > 0.05) {
      final halo = Rect.fromLTWH(rect.left - head * 0.12, -thickness * 0.9, rect.width + head * 0.24, thickness * 2.8);
      final tint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF6EC8FF).withValues(alpha: 0),
            const Color(0xFF6EC8FF).withValues(alpha: 0.10 * prism * strength * fade),
            const Color(0xFFFF9BD1).withValues(alpha: 0.10 * prism * strength * fade),
            const Color(0xFFFFE08A).withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 0.7, 1],
        ).createShader(halo)
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 1.6);
      canvas.drawRect(halo, tint);
    }
  }

  @override
  bool shouldRepaint(_BladePainter old) =>
      old.t != t ||
      old.state != state ||
      old.strength != strength ||
      old.prism != prism ||
      old.accent != accent ||
      old.animate != animate;
}
