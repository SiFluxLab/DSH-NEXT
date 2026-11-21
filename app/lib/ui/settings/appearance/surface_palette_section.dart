// 外观 › 表面配色：黑曜 / 暖炭。
//
// 强调色决定"这个 App 是蓝的还是紫的"，表面配色决定"底色是冷还是暖"。
// 两者正交，所以分成两个入口，不揉成一个"主题"长列表。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/surface_palette_state.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../settings_widgets.dart';

String surfacePaletteLabel(L10n l10n, SurfacePalette palette) => switch (palette) {
  SurfacePalette.obsidian => l10n.surfaceObsidian,
  SurfacePalette.warm => l10n.surfaceWarm,
};

String surfacePaletteHint(L10n l10n, SurfacePalette palette) => switch (palette) {
  SurfacePalette.obsidian => l10n.surfaceObsidianHint,
  SurfacePalette.warm => l10n.surfaceWarmHint,
};

class SurfacePaletteSection extends ConsumerWidget {
  const SurfacePaletteSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(surfacePaletteProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SettingsSection(
      spot: Spots.surface,
      title: l10n.surfacePaletteTitle,
      footer: Text(l10n.surfacePaletteFooter),
      children: [
        for (final palette in SurfacePalette.values)
          SettingsTile(
            key: ValueKey('surface-palette-${palette.name}'),
            title: surfacePaletteLabel(l10n, palette),
            subtitle: surfacePaletteHint(l10n, palette),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Swatch(palette: palette, dark: dark),
                const SizedBox(width: 8),
                Icon(
                  selected == palette ? AppIcons.radioOn : AppIcons.radioOff,
                  size: 24,
                  color: selected == palette ? Theme.of(context).colorScheme.primary : null,
                ),
              ],
            ),
            onTap: () => ref.read(surfacePaletteProvider.notifier).set(palette),
          ),
      ],
    );
  }
}

/// 三格小样：底色 / 卡片 / 强调色，一眼看出冷暖与层次。
class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette, required this.dark});

  final SurfacePalette palette;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = dark ? DshPalette.darkScheme(AppAccent.mist) : DshPalette.lightScheme(AppAccent.mist);
    final swatch = palette.apply(base);
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        width: 46,
        height: 26,
        child: Row(
          children: [
            Expanded(child: ColoredBox(color: swatch.surface)),
            Expanded(child: ColoredBox(color: swatch.surfaceContainerLow)),
            Expanded(child: ColoredBox(color: scheme.primary.withValues(alpha: 0.75))),
          ],
        ),
      ),
    );
  }
}
