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
    final ratio = usage.ratio;
    // 平时**不画**这条线。
    //
    // 它是"还能装多少"的进度条，只有在快满的时候才有信息量；常驻就变成输入框上方
    // 一条说不清来历的横线（用户原话）。所以阈值 80% 以下完全不出现，也不占位。
    if (ratio == null || ratio < 0.8) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final optics = Optics.of(context);
    // 到了这里 ratio 一定非空且 ≥ 0.8：85% 以后变暖、95% 变红。
    final color = ratio >= 0.95 ? scheme.error : scheme.tertiary;
    final target = ratio;
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
                    color: color.withValues(alpha: 0.9),
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

  /// ≥1e6 用 M、≥1e3 用 k，一位小数并去掉尾部 .0；未知写「—」而不是 0。
  static String _num(int? v) {
    if (v == null) return '—';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final ratio = usage.ratio;
    // 85% 是 prism 的临界线：到这儿开始变暖，提醒"该压缩了"。
    final warn = ratio != null && ratio >= 0.85;
    final tone = ratio == null
        ? scheme.onSurfaceVariant
        : warn
        ? scheme.tertiary
        : scheme.primary;
    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.contextTideTitle, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (ratio != null)
                Text(
                  '${(ratio * 100).round()}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: tone,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
        // 分段条：已用 vs 剩余，6.5 高、内距 1、圆角 999；85% 处一条刻度线。
        if (ratio != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Container(
                    height: 6.5,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0),
                    child: Container(
                      height: 6.5,
                      decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                  Positioned(
                    left: box.maxWidth * 0.85,
                    top: -2,
                    bottom: -2,
                    child: Container(width: 1, color: scheme.tertiary.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ),
        row(l10n.contextTideUsed, _num(usage.used)),
        row(l10n.contextTideCached, _num(usage.cached)),
        row(l10n.contextTideOutput, _num(usage.output)),
        row(l10n.contextTideWindow, usage.window == null ? l10n.contextTideUnknown : _num(usage.window)),
        const SizedBox(height: 10),
      ],
    );
  }
}
