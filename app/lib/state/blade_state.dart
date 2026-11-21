import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/optics.dart';

/// 光刃读的状态：全 App 一份，由"正在被看的那件事"来写。
///
/// 为什么是全局而不是每个页面各算一份：光刃表达的是"引擎现在在干什么"，
/// 而这个事实不随页面切换变化。写的人只有一个（对话页），读的人很多（每个页面顶沿）。
class BladeStatus extends Notifier<BladeState> {
  @override
  BladeState build() => BladeState.idle;

  void set(BladeState next) {
    if (state != next) state = next;
  }

  void reset() => set(BladeState.idle);
}

final bladeStatusProvider = NotifierProvider<BladeStatus, BladeState>(BladeStatus.new);

/// 边缘余晖的三种"值得说一句"的状态。null = 不亮。
enum EdgeGlow {
  /// 等你决定：审批、提问、选项。
  awaiting,

  /// 这一轮异常中止。
  aborted,

  /// 后台任务跑完了。
  finished,
}

class EdgeGlowStatus extends Notifier<EdgeGlow?> {
  @override
  EdgeGlow? build() => null;

  void show(EdgeGlow glow) => state = glow;

  void clear() => state = null;
}

final edgeGlowProvider = NotifierProvider<EdgeGlowStatus, EdgeGlow?>(EdgeGlowStatus.new);
