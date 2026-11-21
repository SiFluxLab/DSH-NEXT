// 外观 › 光感与动效：三档预设 + 一条实时预览。
//
// 只暴露"整体选一档"，不把六个数值散成六个开关：用户想的是"要多少光"，
// 不是"镜面高光系数调到 0.06"。系统偏好（移除动画、关闭玻璃模糊、省电模式）
// 依旧在渲染层叠加，见 Optics.resolve。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/optics_state.dart';
import '../../../ui/theme/theme.dart';
import '../../common/light_blade.dart';
import '../settings_widgets.dart';

String opticsPresetLabel(L10n l10n, OpticsPreset preset) => switch (preset) {
  OpticsPreset.full => l10n.opticsFull,
  OpticsPreset.focus => l10n.opticsFocus,
  OpticsPreset.silent => l10n.opticsSilent,
};

String opticsPresetHint(L10n l10n, OpticsPreset preset) => switch (preset) {
  OpticsPreset.full => l10n.opticsFullHint,
  OpticsPreset.focus => l10n.opticsFocusHint,
  OpticsPreset.silent => l10n.opticsSilentHint,
};

class OpticsSection extends ConsumerWidget {
  const OpticsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(opticsPrefsProvider);
    final preset = prefs.preset;
    final optics = Optics.of(context);
    return SettingsSection(
      spot: Spots.optics,
      title: l10n.opticsTitle,
      footer: Text(l10n.opticsFooter),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: _BladePreview(optics: optics),
        ),
        SettingsSegmentTile<OpticsPreset>(
          key: const ValueKey('optics-preset'),
          title: l10n.opticsPreset,
          segments: [
            for (final p in OpticsPreset.values) PillSegment(p, opticsPresetLabel(l10n, p)),
          ],
          selected: preset,
          onChanged: (value) => ref.read(opticsPrefsProvider.notifier).setPreset(value),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            opticsPresetHint(l10n, preset),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        // 单项否决：档位定基调，这里关掉自己不想看的那一项。
        SettingsSwitchTile(
          key: const ValueKey('optics-blade'),
          title: l10n.opticsBlade,
          subtitle: l10n.opticsBladeHint,
          value: optics.blade > 0,
          onChanged: (value) => ref.read(opticsPrefsProvider.notifier).setBlade(value),
        ),
        SettingsSwitchTile(
          key: const ValueKey('optics-prism'),
          title: l10n.opticsPrism,
          subtitle: l10n.opticsPrismHint,
          value: optics.prism > 0,
          onChanged: (value) => ref.read(opticsPrefsProvider.notifier).setPrism(value),
        ),
        SettingsSwitchTile(
          key: const ValueKey('optics-anticipation'),
          title: l10n.opticsAnticipation,
          subtitle: l10n.opticsAnticipationHint,
          value: optics.anticipation,
          onChanged: (value) => ref.read(opticsPrefsProvider.notifier).setAnticipation(value),
        ),
        SettingsSwitchTile(
          key: const ValueKey('optics-afterglow'),
          title: l10n.opticsAfterglow,
          subtitle: l10n.opticsAfterglowHint,
          value: optics.afterglow,
          onChanged: (value) => ref.read(opticsPrefsProvider.notifier).setAfterglow(value),
        ),
        SettingsSwitchTile(
          key: const ValueKey('optics-ink-fade'),
          title: l10n.opticsInkFade,
          subtitle: l10n.opticsInkFadeHint,
          value: optics.inkFade,
          onChanged: (value) => ref.read(opticsPrefsProvider.notifier).setInkFade(value),
        ),
        if (prefs.hasOverrides)
          SettingsTile(
            key: const ValueKey('optics-follow'),
            title: l10n.opticsFollowPreset,
            chevron: false,
            onTap: () => ref.read(opticsPrefsProvider.notifier).followPreset(),
          ),
      ],
    );
  }
}

/// 一格小预览：把光刃放在一块玻璃上，让人当场看出档位差别。
class _BladePreview extends StatelessWidget {
  const _BladePreview({required this.optics});

  final Optics optics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.surfaceContainerHighest, scheme.surfaceContainerLow],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 1,
              child: LightBlade(state: BladeState.streaming, radius: 14, color: scheme.primary),
            ),
            Center(
              child: Text(
                optics.preset.name,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
