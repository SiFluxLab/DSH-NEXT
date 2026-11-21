import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../runtime/runtime_bridge.dart';
import '../../runtime/runtime_state.dart';
import '../common/app_sheet.dart';
import '../common/brief_notice.dart';
import '../common/list_page_row.dart';
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
    final fallback = status.directEngineFallbackReason;
    final directFailed = fallback == 'directFailed';
    // A tawcroot start's fallback is the tawcroot switch's to explain.
    final runtimeNeedsCompatible =
        !status.tawcEngineEnabled &&
        fallback != null &&
        fallback != 'safeRecovery' &&
        !directFailed &&
        !fallback.startsWith('tawcroot');
    final tawcFailed = fallback == 'tawcrootFailed';
    final ztFailed = fallback == 'yinglongFailed';
    final ztEnabled =
        runtime.loaded && stopped && !_saving && (status.yinglongEngineAvailable || status.yinglongEngineEnabled);
    final ztHint = !status.yinglongEngineAvailable
        ? l10n.yinglongEngineUnavailable
        : ztFailed && !status.yinglongEngineEnabled
        ? l10n.yinglongEngineFailedHint
        : !stopped
        ? l10n.phoneDirectStopFirst
        : status.inSafeMode
        ? l10n.phoneDirectSafeHint
        : l10n.yinglongEngineHint;
    final tawcEnabled =
        runtime.loaded && stopped && !_saving && (status.tawcEngineAvailable || status.tawcEngineEnabled);
    final tawcHint = !status.tawcEngineAvailable
        ? l10n.phoneTawcUnavailable
        : tawcFailed && !status.tawcEngineEnabled
        ? l10n.phoneTawcFailedHint
        : status.tawcEngineEnabled && fallback != null && fallback != 'safeRecovery'
        ? l10n.phoneDirectCompatibleHint
        : !stopped
        ? l10n.phoneDirectStopFirst
        : status.inSafeMode
        ? l10n.phoneDirectSafeHint
        : l10n.phoneTawcHint;
    final hint = !status.directEngineAvailable
        ? l10n.phoneDirectNeedsRuntime
        : directFailed && !status.directEngineEnabled
        ? l10n.phoneDirectFailedHint
        : runtimeNeedsCompatible
        ? l10n.phoneDirectCompatibleHint
        : !stopped
        ? l10n.phoneDirectStopFirst
        : status.inSafeMode
        ? l10n.phoneDirectSafeHint
        : l10n.phoneDirectHint;

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
        SettingsTile(
          key: const ValueKey('launch-engine'),
          title: l10n.launchEngine,
          subtitle: status.yinglongEngineEnabled ? l10n.launchEngineZeroTrapHint : tawcHint,
          value: status.yinglongEngineEnabled ? l10n.launchEngineZeroTrap : l10n.launchEngineTawc,
          chevron: true,
          onTap: enabled ? _pickEngine : null,
        ),
      ],
    );
  }

  Future<void> _pickEngine() async {
    final l10n = context.l10n;
    final zt = statusOf(ref);
    final pick = await showAppSheet<String>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListPageRow(
            title: l10n.launchEngineZeroTrap,
            subtitle: l10n.launchEngineZeroTrapHint,
            trailing: zt ? const Icon(Icons.check, size: 18) : null,
            onTap: () => Navigator.of(sheet).pop('zt'),
          ),
          ListPageRow(
            title: l10n.launchEngineTawc,
            subtitle: l10n.phoneTawcHint,
            trailing: zt ? null : const Icon(Icons.check, size: 18),
            onTap: () => Navigator.of(sheet).pop('tawc'),
          ),
        ],
      ),
    );
    if (pick == null) return;
    setState(() => _saving = true);
    try {
      final bridge = ref.read(runtimeBridgeProvider);
      if (pick == 'zt') {
        if (ref.read(runtimeStatusProvider).value?.tawcEngineEnabled ?? false) await bridge.setTawcEngine(false);
        await bridge.setYinglongEngine(true);
      } else {
        if (ref.read(runtimeStatusProvider).value?.yinglongEngineEnabled ?? false) await bridge.setYinglongEngine(false);
        await bridge.setTawcEngine(true);
      }
    } catch (_) {
      if (mounted) showBriefNotice(context, l10n.phoneDirectChangeFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool statusOf(WidgetRef ref) =>
      ref.read(runtimeStatusProvider).value?.yinglongEngineEnabled ?? true;

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
