// 抽屉的第二页：这个会话的工作区文件。
//
// 复用 `ui/session/workspace_files.dart` 里已经做好的 `WorkspaceFilesTab`，
// 不另写一套浏览/预览逻辑——两处行为不一致比少一个入口更糟。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/sessions_state.dart';
import '../../common/empty_view.dart';
import '../../session/workspace_files.dart';

class DrawerFilesPage extends ConsumerWidget {
  const DrawerFilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessionId = ref.watch(currentSessionProvider);
    if (sessionId == null) {
      return EmptyView(
        icon: Icons.folder_outlined,
        title: l10n.drawerFilesEmptyTitle,
        message: l10n.drawerFilesEmptyNote,
      );
    }
    return WorkspaceFilesTab(sessionId: sessionId);
  }
}
