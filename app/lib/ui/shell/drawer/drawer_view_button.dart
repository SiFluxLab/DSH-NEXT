// 「对话列表」选项：工作区行末尾那颗 36 的圆键。
//
// 它原本和状态筛选胶囊住在同一个文件里；筛选收成一枚胶囊之后，这里只留下这颗键。
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';

class DrawerViewButton extends StatelessWidget {
  const DrawerViewButton({super.key, required this.onTap});

  final VoidCallback onTap;

  /// Visible circle and tap target (the workspace row's height).
  static const size = 36.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Tooltip(
      message: l10n.shellChatList,
      child: Semantics(
        button: true,
        label: l10n.shellChatList,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Icon(AppIcons.more, size: 20, color: DshColors.of(context).textTertiary),
            ),
          ),
        ),
      ),
    );
  }
}
