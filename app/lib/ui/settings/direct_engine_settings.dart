import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../runtime/runtime_bridge.dart';
import '../../runtime/runtime_state.dart';
import '../common/brief_notice.dart';
import 'settings_widgets.dart';

/// Direct launch (off by default) and tawcroot launch (on by default), at most one on; a
/// change applies only after a deliberate engine stop/start.
class DirectEngineSettings extends ConsumerStatefulWidget {
  const DirectEngineSettings({super.key});

  @override
  ConsumerState<DirectEngineSettings> createState() => _DirectEngineSettingsState();
}

class _DirectEngineSettingsState extends ConsumerState<DirectEngineSettings> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(localRuntimeProvider);
    final status = runtime.status;
    final l10n = context.l10n;
    final stopped = !status.phase.isBusy && status.phase != RuntimePhase.running;
    final enabled =
        runtime.loaded && stopped && !_saving && (status.directEngineAvailable || status.directEngineEnabled);
    // Safe mode launches compatibly by design: not a sign the runtime needs it.
    // After Direct failed to launch, native reports the switch off until the
    // user turns it on again (a new try).
    return SettingsSection(
      title: l10n.phoneDeveloperOptions,
      children: [
        // Only after a direct launch failed: a fallback already runs compatibly
        // and the switch's hint says so.
        if (status.directEngineEnabled && status.launchSelectedMode == 'direct' && status.launchFailureReason != null)
          SettingsTile(
            title: l10n.phoneReturnCompatible,
            subtitle: stopped ? null : l10n.phoneDirectStopFirst,
            onTap: enabled ? () => _change(false) : null,
          ),
        // 兼容启动：**只有两种**——Zero Trap（默认）与 TawcRoot。
        // 之前是三枚独立开关（direct / 应龙 / tawc），互斥关系靠"至多开一个"的约定维持，
        // 用户看不懂"为什么开了一个会关掉另一个"。改成单选的入口行。
        // 行自己包一层 Builder:面板要知道"从哪一行长出来",所以得拿到这一行的
        // context(它的 RenderBox),而不是整张卡的。
        Builder(
          builder: (rowContext) => SettingsTile(
            key: const ValueKey('launch-engine'),
            title: l10n.launchEngine,
            // 换引擎时说明**原地**换一句(120ms 淡入),行高不变:手指还在这一行
            // 上,页面不该跟着跳一下。
            subtitleWidget: FadingHint(
              status.yinglongEngineEnabled ? l10n.launchEngineZeroTrapHint : l10n.phoneTawcHint,
            ),
            value: Text(status.yinglongEngineEnabled ? l10n.launchEngineZeroTrap : l10n.launchEngineTawc),
            chevron: true,
            onTap: enabled ? () => _pickEngine(rowContext) : null,
          ),
        ),
      ],
    );
  }

  /// [rowContext] 是这一行自己的 context:面板从它长出来、收起时缩回它。
  Future<void> _pickEngine(BuildContext rowContext) async {
    final l10n = context.l10n;
    final zt = ref.read(localRuntimeProvider).status.yinglongEngineEnabled;
    final pick = await showSettingsPicker<String>(
      context,
      title: l10n.launchEngine,
      selected: zt ? 'zt' : 'tawc',
      // 量不到(行还没布局/已回收)时传 null:面板只淡入,不做"长出"。
      origin: settingsRowOrigin(rowContext),
      choices: [
        SettingsChoice('zt', l10n.launchEngineZeroTrap, note: l10n.launchEngineZeroTrapHint),
        SettingsChoice('tawc', l10n.launchEngineTawc, note: l10n.phoneTawcHint),
      ],
    );
    if (pick == null) return;
    setState(() => _saving = true);
    try {
      final bridge = ref.read(runtimeBridgeProvider);
      if (pick == 'zt') {
        if (ref.read(localRuntimeProvider).status.tawcEngineEnabled) {
          await bridge.setTawcEngine(false);
        }
        await bridge.setYinglongEngine(true);
      } else {
        if (ref.read(localRuntimeProvider).status.yinglongEngineEnabled) {
          await bridge.setYinglongEngine(false);
        }
        await bridge.setTawcEngine(true);
      }
    } catch (_) {
      if (mounted) showBriefNotice(context, l10n.phoneDirectChangeFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _change(bool value) async {
    setState(() => _saving = true);
    try {
      await ref.read(runtimeBridgeProvider).setDirectEngine(value);
    } catch (_) {
      if (mounted) showBriefNotice(context, context.l10n.phoneDirectChangeFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
