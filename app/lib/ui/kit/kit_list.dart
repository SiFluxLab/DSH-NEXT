// 列表行与分组卡片：14/500 标题 + 12/70% 说明 + 0.5px 分隔 + 44 行高。
//
// 数值出处（每一处都对着规格抄，别在这里临时改数）：
// - 行高 44：theme-ui 规格 §3.1 的设置项行 ≈44+，同时正好是触控最小命中尺寸；
//   两行（有说明）的取 56 —— 这两个数只写在 [Kit.rowHeight] / [Kit.rowHeightTwo]，
//   设置页和列表页共用一份，免得两处慢慢分叉；
// - 标题 14/500：§3.1「13px / font-medium」在手机触控密度上抬一档（14），
//   字重仍是 500 —— 列表靠 muted 阶梯拉层级，不靠字号变大；
// - 说明 12/70%：page-composition 规格 §7.8「二级文字固定三档」的元信息档，
//   用半透明而不是另一个灰阶，换主题时不会跑偏；
// - 行内距 14/12：§2.1 内容卡 `px-3.5 pt-3 pb-3` = 左右 14、上下 12；
// - 卡片：实色面 + 1px 实线边 + 圆角 12（§2.2「分区卡是 1px 实线 --border，
//   不用半透明边框」，圆角取 `rounded-xl` = 12）；
// - 行间 0.5px：§3.2 与 §6.1 的「半像素描边」是这套界面唯一的细分隔厚度；
//   换成 1px 会把密集列表读成表格。
//
// 为什么不复用 `ListPageRow` / `SettingsTile`：那两个是"设置手册页"的行
// （52–64 高、20 号图标、右缘留 ›），这里是列表页的密行。同一屏混用会出现两种
// 行高与两种图标尺寸，而两者的差别正是**密度**，共用一个类只会把密度搅乱。
// 行间的细线直接复用 [KitRowList]，颜色沿用 [KitCard] 的同一对 token
// （`surfaceContainerLow` / `outlineVariant`），所以工坊、酒馆、设置三处的卡
// 看起来是同一种材质。
import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'kit.dart';

/// 分组卡片里一行所处的位置：决定哪几条边画 1px 实线、哪两个角圆。
enum KitRowPosition {
  single,
  first,
  middle,
  last;

  bool get isFirst => this == single || this == first;
  bool get isLast => this == single || this == last;
}

/// 一行列表内容（外壳由 [KitRowSurface] / [KitRowCard] 给）：图标 · 标题 · 说明 · 右侧动作。
///
/// ```dart
/// KitRow(
///   leading: WorkshopEntryAvatar(entry, size: 32),
///   title: '手感调校',
///   note: '作者 · 让输入更跟手',
///   trailing: WorkshopGetButton(state: WorkshopGetState.get),
///   onTap: open,
/// )
/// ```
class KitRow extends StatelessWidget {
  const KitRow({
    super.key,
    this.leading,
    this.leadingWidth = iconSlot,
    required this.title,
    this.titleStyle,
    this.note,
    this.noteColor,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.chevron = false,
    this.minHeight,
    this.padding = contentPadding,
  });

  /// 图形位：图标、头像、状态点。[leadingWidth] 默认 32，头像这类方块传 32 时
  /// 刚好等于规格里的图标砖尺寸。
  final Widget? leading;
  final double leadingWidth;
  final String title;

  /// 换掉标题样式（等宽命令行、危险行）。
  final TextStyle? titleStyle;

  /// 第二行说明，12 号、70%。
  final String? note;
  final Color? noteColor;

  /// 右侧动作。行尾按钮用 [KitButton] 的 `field` 变体，别另画一个胶囊。
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 行尾补一个 ›（只在"点进下一页"的行上开）。
  final bool chevron;

  /// 整行最低高度；省略时按有没有说明取 [Kit.rowHeight] / [Kit.rowHeightTwo]。
  final double? minHeight;
  final EdgeInsetsGeometry padding;

  /// 图标 18：标题 14 时图标只比字大 4，视觉上才是"同一句话"的一部分。
  static const iconSize = 18.0;

  /// 图形位的宽：图标居中在 32 格里，标题左缘才对齐。
  static const iconSlot = 32.0;

  /// 内距 14/12（规格 §2.1 内容卡）。
  static const contentPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 12);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = DshColors.of(context);
    final titleStyle =
        this.titleStyle ??
        TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w500, color: scheme.onSurface);
    final note = this.note;
    final two = note != null && note.isNotEmpty;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight ?? (two ? Kit.rowHeightTwo : Kit.rowHeight)),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading case final leading?) ...[
              SizedBox(width: leadingWidth, child: Center(child: leading)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                  // 这里重复写一次判空而不是用 [two]：只有写在集合 if 的条件里，
                  // Dart 才会把 note 提升成非空。
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: noteColor ?? colors.textTertiary.withValues(alpha: 0.70),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing case final trailing?) ...[const SizedBox(width: 12), trailing],
            if (chevron) ...[
              const SizedBox(width: 4),
              Icon(AppIcons.disclosure, size: 18, color: colors.textTertiary),
            ],
          ],
        ),
      ),
    );
    if (onTap == null && onLongPress == null) return row;
    return InkWell(onTap: onTap, onLongPress: onLongPress, child: row);
  }
}

/// 分组卡片里**一行的外壳**：实色面 + 1px 实线边 + 圆角 12（只首末行圆）
/// + 行间 0.5px 分隔。
///
/// 为什么行外壳要自己画边：懒加载的 `SliverList` 里没法把整张卡包起来，
/// 只能逐行拼——首行画上缘、末行画下缘，中间行只留一条 0.5px，拼出来才是
/// 一张连续的分组卡，而不是一叠各自带边框的条。
class KitRowSurface extends StatelessWidget {
  const KitRowSurface({super.key, this.position = KitRowPosition.single, required this.child});

  final KitRowPosition position;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = position.isFirst;
    final last = position.isLast;
    final radius = BorderRadius.vertical(
      top: Radius.circular(first ? Kit.radiusPanel : 0),
      bottom: Radius.circular(last ? Kit.radiusPanel : 0),
    );
    final edge = BorderSide(color: scheme.outlineVariant, width: 1);
    // 底色与边线分两层画：`Border` 四边宽度不同时（上 1/中 0.5/下无）**不能**同时给
    // `borderRadius`（Flutter 断言 "A borderRadius can only be given for uniform
    // borders"），所以圆角交给外层 ClipRRect，内部只画直边的这幅框，四角由裁剪切出来。
    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: scheme.surfaceContainerLow,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // 外缘 1px 实线；组内上缘 0.5px；下缘只有末行有（否则行间会叠成 1.5px）。
            border: Border(
              top: first ? edge : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 0.5),
              bottom: last ? edge : BorderSide.none,
              left: edge,
              right: edge,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 一张 12 圆角的分区卡，行与行之间 0.5px：工坊、酒馆、筛选面板里的短分组。
///
/// 结构 = [KitCard] 的那一层材质，只是换成 `Material` 而不是 `DecoratedBox`：
/// 行里的水波要落在**卡片自己**的材质上，否则它画在宿主 Material 上、被卡的
/// 实色面盖住，按下去什么都不亮。
class KitRowCard extends StatelessWidget {
  const KitRowCard({super.key, required this.children, this.margin});

  final List<Widget> children;

  /// 卡外的留白；不传就贴着调用方给的位置。
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Material(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(Kit.radiusPanel),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: KitRowList(children: children),
    );
    final margin = this.margin;
    return margin == null ? card : Padding(padding: margin, child: card);
  }
}

/// 单独一张**条目卡**：实色面 + 1px 实线边 + 圆角 12 + 内距 14/12
/// （规格 §2.1 内容卡 `rounded-xl bg-card px-3.5 pt-3 pb-3`）。
///
/// 和 [KitRowCard] 的分工：一条数据一张卡用这个（网格里的角色、会话卡），
/// 多条数据共用一张卡用 [KitRowCard]。
class KitItemCard extends StatelessWidget {
  const KitItemCard({
    super.key,
    required this.child,
    this.padding = KitRow.contentPadding,
    this.onTap,
    this.onLongPress,
    this.margin,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? margin;

  /// 覆盖卡片面（选中 / 危险这类整卡语义），默认 `surfaceContainerLow`。
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(Kit.radiusPanel);
    final card = Material(
      color: tint ?? scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedSuperellipseBorder(borderRadius: radius, side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: RoundedSuperellipseBorder(borderRadius: radius),
        child: Padding(padding: padding, child: child),
      ),
    );
    final margin = this.margin;
    return margin == null ? card : Padding(padding: margin, child: card);
  }
}
