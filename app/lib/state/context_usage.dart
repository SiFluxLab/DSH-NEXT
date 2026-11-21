import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_state.dart';
import 'providers_state.dart';

/// 一个会话"上一次请求吃掉了多少上下文"，以及窗口有多大（知道才给）。
///
/// 数字全部来自引擎回报的 `TokenUsage`：缓存命中的部分同样占着上下文，所以
/// 已用 = 未命中输入 + 缓存读 + 缓存写。窗口只在配置里能查到该模型时才给——
/// 查不到就只报已用，**不给分母**，不编一个数出来。
class ContextUsage {
  const ContextUsage({required this.used, this.window, required this.output, required this.cached});

  /// 上一次请求的提示规模（估算上下文占用）。
  final int used;

  /// 模型的上下文窗口；未知为 null。
  final int? window;

  /// 那次请求的输出量（仅供拆分展示）。
  final int output;

  /// 其中命中缓存的部分。
  final int cached;

  /// 已用 / 窗口；窗口未知时为 null。
  double? get ratio => window == null || window! <= 0 ? null : (used / window!).clamp(0.0, 1.0);
}

/// 每个会话一份，跟着 chat 状态走；没有用量数据时为 null。
final contextUsageProvider = Provider.autoDispose.family<ContextUsage?, String>((ref, sessionId) {
  final chat = ref.watch(chatProvider(sessionId));
  // 从尾部找最近一条带用量的回复：它是"上一次请求"的真实规模。
  for (var i = chat.items.length - 1, seen = 0; i >= 0 && seen < 24; i--, seen++) {
    final item = chat.items[i];
    if (item is! AssistantChatItem) continue;
    final u = item.usage;
    if (u == null) continue;
    final cached = (u.cacheReadTokens ?? 0) + (u.cacheWriteTokens ?? 0);
    return ContextUsage(
      used: u.inputTokens + cached,
      output: u.outputTokens,
      cached: cached,
      window: _windowFor(ref, chat.model),
    );
  }
  return null;
});

/// 当前模型声明的窗口：先看该模型自己的覆盖值，再看路由的默认值。
/// 路由没配置就返回 null（宁可没有分母，也不编一个出来）。
int? _windowFor(Ref ref, ModelSelection? model) {
  if (model == null) return null;
  final snapshot = ref.watch(customProvidersProvider).value;
  if (snapshot == null) return null;
  for (final provider in snapshot.providers) {
    if (provider.id != model.provider) continue;
    for (final spec in provider.models) {
      if (spec.id == model.model && spec.contextWindow != null) return spec.contextWindow;
    }
    return provider.defaults.contextWindow;
  }
  return null;
}
