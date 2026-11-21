// 思考档位滑块——按 prism 的真实规则重写。
//
// 之前那版只有"星空"，看不出当前强度：prism 的强度信息根本不靠星星，
// 靠三样东西（都来自它的 CSS）：
//   1. **刻度是 2×8 的竖胶囊**（不是小圆点），当前档位及以下的刻度是 "is-on"：
//      亮底 + 0.5px 反向描边——所以"我现在在第几档"一眼可见；
//   2. **填充**：从左边到旋钮一段渐变，外加旋钮附近更亮的"能量"层；
//   3. **数值文字**：11.5/600 等宽、字距 .03em、渐变字。
// 旋钮 22×22，深色渐变 + 内高光 + 一圈 1.6px 的**棱镜环**（钴蓝/鸢尾/珊瑚/琥珀）。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/spectral.dart';

class EffortSlider extends StatefulWidget {
  const EffortSlider({
    super.key,
    required this.levels,
    required this.index,
    required this.onChanged,
    this.enabled = true,
  });

  /// 从低到高的档位标签（"低 / 中 / 高 / 极高"）。
  final List<String> levels;
  final int index;
  final ValueChanged<int>? onChanged;
  final bool enabled;

  @override
  State<EffortSlider> createState() => _EffortSliderState();
}

class _EffortSliderState extends State<EffortSlider> {
  bool _dragging = false;

  static const _golden = 0.6180339887;
  static const _stars = 20;
  static const _knob = 22.0;
  static const _trackH = 28.0;

  int _indexAt(double dx, double width) {
    final last = widget.levels.length - 1;
    if (last <= 0) return 0;
    final usable = math.max(1.0, width - _knob);
    final t = ((dx - _knob / 2) / usable).clamp(0.0, 1.0);
    return (t * last).round();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = widget.levels.length - 1;
    final safeIndex = widget.index.clamp(0, math.max(0, last));
    final t = last <= 0 ? 0.0 : safeIndex / last;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.quick;
    final label = widget.levels.isEmpty ? '' : widget.levels[safeIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 头部：当前档位名 + 数值感（prism 用等宽渐变字显示强度）
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.03,
                color: scheme.onSurface.withValues(alpha: 0.92),
              ),
            ),
            const Spacer(),
            Text(
              '${safeIndex + 1}/${widget.levels.length}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.03,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            final knobLeft = (width - _knob) * t;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: widget.enabled
                  ? (d) {
                      setState(() => _dragging = true);
                      widget.onChanged?.call(_indexAt(d.localPosition.dx, width));
                    }
                  : null,
              onHorizontalDragUpdate: widget.enabled
                  ? (d) => widget.onChanged?.call(_indexAt(d.localPosition.dx, width))
                  : null,
              onHorizontalDragEnd: widget.enabled ? (_) => setState(() => _dragging = false) : null,
              onTapUp: widget.enabled ? (d) => widget.onChanged?.call(_indexAt(d.localPosition.dx, width)) : null,
              child: Semantics(
                slider: true,
                value: label,
                child: SizedBox(
                  height: _trackH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 轨道
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.onSurface.withValues(alpha: 0.055),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      // 填充 + 能量 + 星点：一个 painter，避免三层叠加各算一次
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _TrackPainter(
                              t: t,
                              knobLeft: knobLeft,
                              knobWidth: _knob,
                              stars: _stars,
                              phase: _golden,
                              levels: widget.levels.length,
                              tint: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      // 刻度：2×8 竖胶囊，当前档及以下是 is-on
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _Ticks(levels: widget.levels.length, index: safeIndex, dark: Theme.of(context).brightness == Brightness.dark),
                          ),
                        ),
                      ),
                      // 旋钮
                      AnimatedPositioned(
                        duration: duration,
                        curve: AppMotion.swift,
                        left: knobLeft,
                        top: (_trackH - _knob) / 2,
                        child: AnimatedScale(
                          duration: duration,
                          scale: _dragging ? 0.94 : 1,
                          child: const _Knob(size: _knob),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 深色渐变 + 内高光 + 一圈 1.6px 棱镜环（钴蓝 → 鸢尾 → 珊瑚 → 琥珀）。
class _Knob extends StatelessWidget {
  const _Knob({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _KnobPainter(size: size, dark: dark),
        child: Center(
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: dark ? 0.55 : 0.9),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter({required this.size, required this.dark});

  final double size;
  final bool dark;

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    final rrect = RRect.fromRectAndRadius(rect.deflate(0.8), Radius.circular(size));
    // 本体：上亮下暗的深色渐变（暗色）／白瓷（亮色）
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF3B465E), Color(0xFF2A3346), Color(0xFF202738)]
              : const [Color(0xFFFFFFFF), Color(0xFFF1F4FA)],
        ).createShader(rect),
    );
    // 内高光：inset 0 1px 0 rgba(255,255,255,.26)
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1.4), Radius.circular(size)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: dark ? 0.26 : 0.7),
    );
    // 棱镜环：1.6px，用扫描渐变绕一圈
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.8), Radius.circular(size)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = SweepGradient(
          colors: [
            Spectral.ramp[0],
            Spectral.ramp[2],
            Spectral.ramp[3],
            const Color(0xFFFBBC04),
            Spectral.ramp[0],
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.dark != dark || old.size != size;
}

class _Ticks extends CustomPainter {
  _Ticks({required this.levels, required this.index, required this.dark});

  final int levels;
  final int index;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels < 2) return;
    const knob = 22.0;
    final usable = size.width - knob;
    for (var i = 0; i < levels; i++) {
      final x = knob / 2 + usable * (i / (levels - 1));
      final on = i <= index;
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, size.height / 2), width: 2, height: 8),
        const Radius.circular(999),
      );
      if (on) {
        // is-on：亮底 + 0.5px 反向描边，所以"到第几档"一眼可见
        canvas.drawRRect(r, Paint()..color = dark ? const Color(0xFFD6E4FC) : const Color(0xFF1E293B).withValues(alpha: 0.85));
        canvas.drawRRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..color = dark ? const Color(0xFF0A0E18).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.8),
        );
      } else {
        canvas.drawRRect(r, Paint()..color = (dark ? const Color(0xFFD6E4FC) : const Color(0xFF475569)).withValues(alpha: 0.22));
      }
    }
  }

  @override
  bool shouldRepaint(_Ticks old) => old.index != index || old.dark != dark || old.levels != levels;
}

/// 填充（左到旋钮）+ 能量（旋钮附近的亮部）+ 星点。
class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.t,
    required this.knobLeft,
    required this.knobWidth,
    required this.stars,
    required this.phase,
    required this.levels,
    required this.tint,
  });

  final double t;
  final double knobLeft;
  final double knobWidth;
  final int stars;
  final double phase;
  final int levels;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    // 1) 星点：黄金比错开，避免成排
    final starPaint = Paint();
    for (var i = 0; i < stars; i++) {
      final fx = (i * phase) % 1.0;
      final fy = 0.12 + ((i * 0.7548776662) % 1.0) * 0.76;
      starPaint.color = tint.withValues(alpha: 0.10 + 0.14 * (1 - fy));
      canvas.drawCircle(Offset(6 + fx * (size.width - 12), fy * h), 0.9, starPaint);
    }
    // 2) 填充：从左边到旋钮中心，光谱渐变（低档淡、高档亮）
    if (t > 0.01) {
      final end = knobLeft + knobWidth / 2;
      final rect = Rect.fromLTWH(0, 0, end, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(999)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Spectral.ramp[0].withValues(alpha: 0.18 + 0.20 * t),
              Spectral.ramp[2].withValues(alpha: 0.26 + 0.30 * t),
              Spectral.glow.withValues(alpha: 0.35 + 0.40 * t),
            ],
          ).createShader(rect),
      );
      // 3) 能量：旋钮左侧一小段更亮的光，给人"推进去了"的感觉
      final energyRect = Rect.fromLTWH(math.max(0, end - 46), 0, math.min(46, end), h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(energyRect, Radius.circular(999)),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.transparent, Spectral.glow.withValues(alpha: 0.20 + 0.22 * t)],
          ).createShader(energyRect),
      );
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.t != t || old.knobLeft != knobLeft || old.tint != tint;
}
