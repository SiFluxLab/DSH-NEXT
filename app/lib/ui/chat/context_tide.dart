// 上下文潮线：输入条上沿一条 2px 的线，表示上一次请求吃掉了多少上下文。
//
// 参考 obsidian-prism 的「上下文试管」：它把那根试管放在输入框旁，点开看拆分。
// 我们改成贴在输入条上沿的一条线——因为它只用 2px，不占横向空间，而且和
// 「光刃」是同一套语言（状态用一条光表达）。点它同样能看拆分。
//
// 数据只来自引擎回报的 `TokenUsage`；窗口查不到时**不画比例**，也不编分母。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/context_usage.dart';
import '../common/app_sheet.dart';
import '../theme/theme.dart';

class ContextTide extends ConsumerWidget {
  const ContextTide({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(contextUsageProvider(sessionId));
    if (usage == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final optics = Optics.of(context);
    final ratio = usage.ratio;
    // 80% 开始变暖、95% 变红：颜色只是提醒，真正的信息是那条线的长度。
    final color = ratio == null
        ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
        : ratio >= 0.95
        ? scheme.error
        : ratio >= 0.8
        ? scheme.tertiary
        : scheme.primary;
    final target = ratio ?? 1.0;
    final animate = optics.anticipation && !AppMotion.reduced(context);
    return Semantics(
      button: true,
      label: context.l10n.contextTideTitle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showAppSheet<void>(
          context,
          builder: (_) => _ContextSheet(usage: usage),
        ),
        child: SizedBox(
          height: 6,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: target),
              duration: animate ? AppMotion.standard : Duration.zero,
              curve: AppMotion.swift,
              builder: (context, value, _) => FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: ratio == null ? 0.5 : 0.9),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextSheet extends StatelessWidget {
  const _ContextSheet({required this.usage});

  final ContextUsage usage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    String n(int v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : '$v';
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant))),
          Text(value, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Text(l10n.contextTideTitle, style: Theme.of(context).textTheme.titleMedium),
        ),
        row(l10n.contextTideUsed, n(usage.used)),
        row(l10n.contextTideCached, n(usage.cached)),
        row(l10n.contextTideOutput, n(usage.output)),
        row(
          l10n.contextTideWindow,
          usage.window == null ? l10n.contextTideUnknown : n(usage.window!),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
