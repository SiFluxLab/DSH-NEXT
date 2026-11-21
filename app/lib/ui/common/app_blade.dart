// 页面顶沿的光刃：读全局状态，尊重光感档位。
//
// 单独抽出来是为了让 AppPage 不必变成 ConsumerWidget——一个页面框架不该为了
// 一条 1.4px 的线去订阅状态。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/blade_state.dart';
import '../theme/optics.dart';
import 'light_blade.dart';

class AppBlade extends ConsumerWidget {
  const AppBlade({super.key, this.radius = 14});

  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bladeStatusProvider);
    // silent 档连 widget 都不建：LightBlade 内部还会再判一次，但这里先省掉订阅。
    if (Optics.of(context).blade <= 0) return const SizedBox.shrink();
    return LightBlade(state: state, radius: radius);
  }
}

/// 边缘余晖：屏幕四周一层极淡的呼吸光，代表"有件事值得看一眼"，但不打断。
///
/// 不用弹窗、不用角标：它跟着状态出现，状态清掉就消失；动画只做透明度，
/// 不动几何，所以不会引起重排。
class EdgeAfterglow extends ConsumerWidget {
  const EdgeAfterglow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glow = ref.watch(edgeGlowProvider);
    final optics = Optics.of(context);
    if (glow == null || !optics.afterglow) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final color = switch (glow) {
      EdgeGlow.awaiting => scheme.primary,
      EdgeGlow.aborted => scheme.error,
      EdgeGlow.finished => scheme.tertiary,
    };
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.4,
                colors: [
                  color.withValues(alpha: 0.10 * t * optics.blade.clamp(0.35, 1.0)),
                  color.withValues(alpha: 0),
                ],
                stops: const [0.55, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
