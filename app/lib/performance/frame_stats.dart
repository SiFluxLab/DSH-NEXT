import 'dart:async';
import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 滚动窗口里的帧表现：平均值、95 分位、最差一帧、掉帧比例。
class FrameStats {
  const FrameStats({
    this.frames = 0,
    this.avgMs = 0,
    this.p95Ms = 0,
    this.worstMs = 0,
    this.jankRatio = 0,
  });

  final int frames;
  final double avgMs;
  final double p95Ms;
  final double worstMs;

  /// 超过 [jankBudgetMs] 的帧占比。
  final double jankRatio;

  static const jankBudgetMs = 16.7;

  bool get empty => frames == 0;
}

/// 采集器：只留最近 [window] 帧，O(window) 算一次分位，不保留时间序列。
///
/// 为什么用 `addTimingsCallback` 而不是自己算 WidgetsBinding 的帧：它给的是引擎
/// 真实构建+光栅耗时（含 GPU 线程），正是"流畅不流畅"要看的东西。
class FrameStatsService {
  FrameStatsService._();

  static final instance = FrameStatsService._();

  static const window = 240;

  final _samples = Queue<double>();
  bool _installed = false;
  FrameStats _last = const FrameStats();

  FrameStats get latest => _last;

  void install() {
    if (_installed) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback(_accept);
  }

  void _accept(List<FrameTiming> timings) {
    for (final t in timings) {
      // totalSpan 覆盖构建到上屏；rasterDuration 单独看 GPU。
      final ms = t.totalSpan.inMicroseconds / 1000.0;
      if (ms <= 0 || ms > 5000) continue; // 5s 以上是系统挂起，不算帧
      _samples.addLast(ms);
      while (_samples.length > window) {
        _samples.removeFirst();
      }
    }
    if (_samples.isEmpty) return;
    final sorted = _samples.toList()..sort();
    final total = sorted.fold<double>(0, (a, b) => a + b);
    final jank = sorted.where((v) => v > FrameStats.jankBudgetMs).length;
    _last = FrameStats(
      frames: sorted.length,
      avgMs: total / sorted.length,
      p95Ms: sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)],
      worstMs: sorted.last,
      jankRatio: jank / sorted.length,
    );
  }

  void clear() {
    _samples.clear();
    _last = const FrameStats();
  }
}

/// 页面用：每 [frameStatsTick] 读一次最新值，不订阅每帧回调。
final frameStatsProvider = StreamProvider<FrameStats>((ref) {
  // 打开性能页才装：这个回调每帧都会来，不该在没人看的时候常驻。
  FrameStatsService.instance.install();
  final controller = StreamController<FrameStats>();
  final timer = Timer.periodic(frameStatsTick, (_) => controller.add(FrameStatsService.instance.latest));
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  controller.add(FrameStatsService.instance.latest);
  return controller.stream;
});

const frameStatsTick = Duration(seconds: 1);
