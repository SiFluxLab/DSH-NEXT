// 思考档位滑块（prism 的"星空滑块"）。
//
// 它的规格不是"换个滑块样子"，而是一整套：
//   · 轨道高 28，圆角 999，底是极淡的前景；
//   · 轨道里撒 22 颗 3px 星点，y 从 8% 到 92%，亮度 .5→1，**按黄金比错开**，所以不会成排；
//   · 档位数决定刻度点（3×3），档位越高，星点越亮、越密；
//   · 旋钮 28×28 白圆，按下轻微缩小；拖动时星点被"推开"（亮度随距离衰减）。
// 为什么值得照做：它是唯一一个能让人**看出当前档位强度**的控件——分段胶囊只能表示"选了哪个"。
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

  /// 黄金比相位：任意档位下星点都不成排。
  static const _golden = 0.6180339887;
  static const _stars = 22;

  int _indexAt(double dx, double width) {
    final last = widget.levels.length - 1;
    if (last <= 0 || width <= 0) return 0;
    // 两端各留一个旋钮半径，让旋钮不会贴边裁掉。
    const pad = 14.0;
    final usable = math.max(1.0, width - pad * 2);
    final t = ((dx - pad) / usable).clamp(0.0, 1.0);
    return (t * last).round();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = widget.levels.length - 1;
    final t = last <= 0 ? 0.0 : widget.index / last;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.quick;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
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
            value: widget.levels.isEmpty ? '' : widget.levels[widget.index.clamp(0, last)],
            child: SizedBox(
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 轨道
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  // 星点：亮度随"离旋钮的远近"变化——这就是它的科幻感来源。
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _Starfield(
                          t: t,
                          count: _stars,
                          phase: _golden,
                          tint: scheme.onSurface,
                          hot: Spectral.glow,
                          levels: widget.levels.length,
                        ),
                      ),
                    ),
                  ),
                  // 刻度点：档位数
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _Ticks(levels: widget.levels.length, color: scheme.onSurface.withValues(alpha: 0.28)),
                      ),
                    ),
                  ),
                  // 旋钮
                  AnimatedPositioned(
                    duration: duration,
                    curve: AppMotion.swift,
                    left: (width - 28) * t,
                    top: 0,
                    child: AnimatedScale(
                      duration: duration,
                      scale: _dragging ? 0.92 : 1,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Color.lerp(scheme.onSurface.withValues(alpha: 0.35), Spectral.glow, t * t)!,
                              shape: BoxShape.circle,
                            ),
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
      },
    );
  }
}

class _Starfield extends CustomPainter {
  _Starfield({required this.t, required this.count, required this.phase, required this.tint, required this.hot, required this.levels});

  final double t;
  final int count;
  final double phase;
  final Color tint;
  final Color hot;
  final int levels;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      // 横向用黄金比散开，纵向用另一个无理数错开：两者都不可公度，所以永不成排。
      final fx = (i * phase) % 1.0;
      final fy = (0.08 + ((i * 0.7548776662) % 1.0) * 0.84);
      final x = 6 + fx * (size.width - 12);
      final y = fy * size.height;
      // 离旋钮越近越亮：旋钮位置的 x = t*(width-28)+14
      final knobX = t * (size.width - 28) + 14;
      final d = ((x - knobX).abs() / (size.width * 0.45)).clamp(0.0, 1.0);
      final near = 1 - d;
      final base = 0.5 + 0.5 * near;
      // 档位越高整体越亮
      final a = (base * (0.35 + 0.65 * t)).clamp(0.0, 1.0);
      paint.color = Color.lerp(tint.withValues(alpha: a * 0.55), hot.withValues(alpha: a), near * t)!;
      final r = 1.2 + 0.6 * near;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_Starfield old) => old.t != t || old.tint != tint || old.levels != levels;
}

class _Ticks extends CustomPainter {
  _Ticks({required this.levels, required this.color});

  final int levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels < 2) return;
    final paint = Paint()..color = color;
    for (var i = 0; i < levels; i++) {
      final x = 14 + (size.width - 28) * (i / (levels - 1));
      // 刻度画在轨道正中的一小段：3×3 圆点。
      canvas.drawCircle(Offset(x, size.height / 2), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(_Ticks old) => old.levels != levels || old.color != color;
}
