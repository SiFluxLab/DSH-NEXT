// 模型选择卡里的 provider 标识。
//
// 参考 obsidian-prism 的做法：它按模型 id 正则判断品牌，再内联一段 SVG path，
// 色值 claude #D97757 / openai #8A94A6 / gemini #6EA2FF / antigravity #5B93F7。
//
// **我们不用厂商商标**（那是注册商标，不能直接打进包里）。这里改成"同一套几何语言下的
// 抽象标示"：每个家族一种形状 + 一个中性偏冷的品牌色，远看能分辨"这是哪家"，
// 近看不会误认成官方 logo。形状差异在 18px 下仍然可辨（圆 / 圆角方 / 尖三角 / 菱形）。
import 'package:flutter/material.dart';

/// 模型家族。判定顺序照 prism 的正则思路：先认最专有的词，再兜底。
enum ModelFamily { anthropic, openai, google, deepseek, other }

ModelFamily familyOf(String providerId, String modelId) {
  final s = '$providerId $modelId'.toLowerCase();
  if (RegExp(r'claude|sonnet|opus|haiku|anthropic').hasMatch(s)) return ModelFamily.anthropic;
  if (RegExp(r'deepseek').hasMatch(s)) return ModelFamily.deepseek;
  if (RegExp(r'gemini|gemma|google|vertex').hasMatch(s)) return ModelFamily.google;
  if (RegExp(r'gpt|openai|o1|o3|o4|codex').hasMatch(s)) return ModelFamily.openai;
  return ModelFamily.other;
}

/// 品牌色。刻意压低饱和：它是"标识"，不该抢走选中态的注意力。
Color familyTint(ModelFamily family, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (family) {
    ModelFamily.anthropic => dark ? const Color(0xFFD97757) : const Color(0xFFC2603F),
    ModelFamily.openai => dark ? const Color(0xFF8A94A6) : const Color(0xFF5C6673),
    ModelFamily.google => dark ? const Color(0xFF6EA2FF) : const Color(0xFF3F6FD8),
    ModelFamily.deepseek => dark ? const Color(0xFF6E8BFF) : const Color(0xFF4B5FD6),
    ModelFamily.other => dark ? const Color(0xFF9AA0B4) : const Color(0xFF6B7280),
  };
}

/// 18×18 的标识砖：家族色 12% 底 + 家族色描边 + 一个几何内核。
class ProviderGlyph extends StatelessWidget {
  const ProviderGlyph({super.key, required this.providerId, required this.modelId, this.size = 18});

  final String providerId;
  final String modelId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final family = familyOf(providerId, modelId);
    final tint = familyTint(family, Theme.of(context).brightness);
    return Semantics(
      label: family.name,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(size * 0.3),
            border: Border.all(color: tint.withValues(alpha: 0.35), width: 0.5),
          ),
          child: Center(child: CustomPaint(size: Size.square(size * 0.5), painter: _GlyphPainter(family, tint))),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.family, this.color);

  final ModelFamily family;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = size.width / 2;
    final c = Offset(r, r);
    switch (family) {
      case ModelFamily.anthropic:
        // 圆：留一圈呼吸，不画实心。
        canvas.drawCircle(c, r * 0.86, paint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.18);
      case ModelFamily.openai:
        // 圆角方：与圆区分开，但同样"温和"。
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: r * 0.92), Radius.circular(r * 0.42)),
          paint,
        );
      case ModelFamily.google:
        // 尖三角：唯一带尖角的家族，18px 下最好认。
        final path = Path()
          ..moveTo(c.dx, c.dy - r * 0.95)
          ..lineTo(c.dx + r * 0.95, c.dy + r * 0.75)
          ..lineTo(c.dx - r * 0.95, c.dy + r * 0.75)
          ..close();
        canvas.drawPath(path, paint);
      case ModelFamily.deepseek:
        // 菱形。
        final path = Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r, c.dy)
          ..close();
        canvas.drawPath(path, paint);
      case ModelFamily.other:
        // 兜底：两笔横线，读作"通用"。
        final w = size.width;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(0, r * 0.55, w, w * 0.16), Radius.circular(w * 0.08)),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(0, r * 1.35, w, w * 0.16), Radius.circular(w * 0.08)),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.family != family || old.color != color;
}
