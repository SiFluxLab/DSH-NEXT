// 表面配色：把「背景是什么颜色」从强调色里独立出来。
//
// 参考 obsidian-prism 的调色板实现（workbench/styles/v2-tokens.css）：它的好看
// 不在于某个色值，而在于**四段式的表面阶梯**——背景、卡片、悬停、按下，每段只差
// 3–5%，配一条 0.115 透明度的细线和一条 0.095 的顶部镜面高光。这样玻璃叠在任何
// 一层上都成立，界面也因此安静。
//
// 我们把它的两套底色搬过来（各含明暗两面）：
//   黑曜 obsidian：真中性，冷调近黑 #0e0e11 / 冷调雾蓝浅底 #f4f7fb
//   暖炭 warm：   暖炭褐 #10100f / 暖白画册 #f6f4ee
//
// 强调色仍由用户自己的 6 套 accent 决定；这里只替换中性色。
import 'package:flutter/material.dart';

enum SurfacePalette { obsidian, warm }

/// 一套中性色：背景、三层表面、文字阶梯、细线。
@immutable
class _Tones {
  const _Tones({
    required this.background,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.foreground,
    required this.secondary,
    required this.muted,
  });

  final Color background;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color foreground;
  final Color secondary;
  final Color muted;
}

const _obsidianDark = _Tones(
  background: Color(0xFF0E0E11),
  surface1: Color(0xFF151519),
  surface2: Color(0xFF1C1C21),
  surface3: Color(0xFF24242B),
  foreground: Color(0xFFF2F2F5),
  secondary: Color(0xFFBDBDC8),
  muted: Color(0xFF8F8F9C),
);

const _obsidianLight = _Tones(
  background: Color(0xFFF4F7FB),
  surface1: Color(0xFFFFFFFF),
  surface2: Color(0xFFEDF2F9),
  surface3: Color(0xFFE1E9F4),
  foreground: Color(0xFF14171E),
  secondary: Color(0xFF4A5160),
  muted: Color(0xFF6B7280),
);

const _warmDark = _Tones(
  background: Color(0xFF10100F),
  surface1: Color(0xFF1B1A18),
  surface2: Color(0xFF22201D),
  surface3: Color(0xFF2A2824),
  foreground: Color(0xFFF4F1EA),
  secondary: Color(0xFFC3BCAE),
  muted: Color(0xFF968F82),
);

const _warmLight = _Tones(
  background: Color(0xFFF6F4EE),
  surface1: Color(0xFFFFFFFF),
  surface2: Color(0xFFF1EEE5),
  surface3: Color(0xFFE5E0D3),
  foreground: Color(0xFF1C1A16),
  secondary: Color(0xFF55504A),
  muted: Color(0xFF7A7368),
);

extension SurfacePaletteTones on SurfacePalette {
  _Tones tones(Brightness brightness) => switch ((this, brightness)) {
    (SurfacePalette.obsidian, Brightness.dark) => _obsidianDark,
    (SurfacePalette.obsidian, Brightness.light) => _obsidianLight,
    (SurfacePalette.warm, Brightness.dark) => _warmDark,
    (SurfacePalette.warm, Brightness.light) => _warmLight,
  };

  /// 把中性色写进一套 ColorScheme。强调色、语义色（成功/警告/危险）不动：
  /// 那些是"信息"的颜色，不该被底色左右。
  ColorScheme apply(ColorScheme scheme) {
    final t = tones(scheme.brightness);
    final dark = scheme.brightness == Brightness.dark;
    // 细线：深色底用白线、浅色底用黑线，透明度与 prism 的 0.115 一致。
    final line = (dark ? Colors.white : Colors.black).withValues(alpha: 0.115);
    return scheme.copyWith(
      surface: t.background,
      surfaceDim: t.background,
      surfaceBright: t.surface3,
      surfaceContainerLowest: t.surface1,
      surfaceContainerLow: t.surface2,
      surfaceContainer: t.surface2,
      surfaceContainerHigh: t.surface3,
      surfaceContainerHighest: Color.lerp(t.surface3, t.foreground, dark ? 0.06 : 0.04)!,
      onSurface: t.foreground,
      onSurfaceVariant: t.secondary,
      outline: t.muted,
      outlineVariant: line,
      inverseSurface: t.foreground,
      onInverseSurface: t.background,
      scrim: Colors.black,
      shadow: Colors.black,
      surfaceTint: Colors.transparent,
      // 描边在两处被当作"骨架"用，这里的强线给聚焦与分隔。
      secondaryContainer: Color.lerp(t.surface2, t.foreground, dark ? 0.10 : 0.06)!,
      onSecondaryContainer: t.foreground,
      tertiaryContainer: Color.lerp(t.surface2, t.foreground, dark ? 0.08 : 0.05)!,
      onTertiaryContainer: t.foreground,
    );
  }
}

/// 供 UI 预览用：两套底色的代表色（深/浅各一个）。
Color paletteSwatch(SurfacePalette palette, Brightness brightness) => palette.tones(brightness).surface1;
