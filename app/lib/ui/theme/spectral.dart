// 光谱：prism 的"科幻感"来源不是某个蓝色，而是**光被分光**。
//
// 它的 token 里效果用的是一条蓝 → 紫 → 玫的光谱（#4c8df6 → #9b72cb → #d96570），
// 加上一个更亮的辉光蓝（#7aa7f8）和一个提亮的白热头部。单色渐变无论多亮都读作"塑料"，
// 因为现实里没有单色光——这一条是整套观感的分水岭。
import 'package:flutter/material.dart';

abstract final class Spectral {
  /// 分光带：蓝 → 紫 → 玫。顺序不能反，反了就变成"紫红"而不是"棱镜"。
  static const ramp = <Color>[
    Color(0xFF4C8DF6),
    Color(0xFF7AA7F8),
    Color(0xFF9B72CB),
    Color(0xFFD96570),
  ];

  /// 高亮辉光：用在头部与最亮的一段。
  static const glow = Color(0xFF7AA7F8);

  /// 主色（prism 的 accent）：低饱和钢蓝，不是鲜蓝。鲜蓝在近黑底上会"发塑料"。
  static const accent = Color(0xFF5B89D6);

  /// 取光谱上的一点（t ∈ [0,1)），用于随时间漂移色相。
  static Color at(double t) {
    final x = (t % 1.0) * (ramp.length - 1);
    final i = x.floor().clamp(0, ramp.length - 2);
    return Color.lerp(ramp[i], ramp[i + 1], x - i)!;
  }

  /// 三段渐变：给"弧"用。头部亮、尾部暗，中间过渡。
  static List<Color> arc(double phase, double alpha) => [
    at(phase).withValues(alpha: 0),
    at(phase + 0.18).withValues(alpha: alpha * 0.55),
    at(phase + 0.34).withValues(alpha: alpha),
    glow.withValues(alpha: alpha),
    at(phase + 0.34).withValues(alpha: 0),
  ];

  static const stops = <double>[0, 0.35, 0.7, 0.92, 1];
}

/// 加色混合：光叠在背景上应该"变亮"，而不是"盖住"。用 plus 才能在浅色底上也像光。
const kLightBlend = BlendMode.plus;
/// 颗粒：prism 的 `grainAlpha: 0.022`。
///
/// 它的光带不是"平滑渐变"，而是**有噪点**的——那层细颗粒让光看起来在空气里，
/// 而不是贴在玻璃上。做法是在光带上撒极淡的白点，alpha 0.02 左右，肉眼几乎不觉，
/// 但去掉就会立刻回到"UI 特效"。
abstract final class Grain {
  /// 来源：prism 的 `grainAlpha`（0.022）。比它再高就会显脏。
  static const alpha = 0.022;

  /// 沿弧线撒点。用确定性的伪随机，保证同一帧重绘不会闪。
  static void along(
    Canvas canvas,
    Path path, {
    required double alphaScale,
    int count = 220,
    Color tint = const Color(0xFFFFFFFF),
  }) {
    // 不显式命名 PathMetrics：它来自 dart:ui，由 material 间接导出与否不该由调用方决定。
    final metrics = path.computeMetrics().toList();
    if (count <= 0 || alphaScale <= 0) return;
    final paint = Paint()..style = PaintingStyle.fill;
    var seed = 0x9E3779B9;
    double next() {
      // xorshift32：便宜且分布够用，不需要 Random 对象。
      seed ^= (seed << 13) & 0xFFFFFFFF;
      seed ^= seed >> 17;
      seed ^= (seed << 5) & 0xFFFFFFFF;
      return (seed & 0xFFFFFF) / 0xFFFFFF;
    }

    for (final metric in metrics) {
      for (var i = 0; i < count; i++) {
        final at = next() * metric.length;
        final tangent = metric.getTangentForOffset(at);
        if (tangent == null) continue;
        // 垂直方向散开 ±1.6px，落在笔画宽度之内，看起来像"光里的尘"
        final offset = (next() - 0.5) * 3.2;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        final p = tangent.position + normal * offset;
        paint.color = tint.withValues(alpha: alpha * alphaScale * (0.4 + 0.6 * next()));
        canvas.drawCircle(p, 0.6 + 0.5 * next(), paint);
      }
    }
  }
}
