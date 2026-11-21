// Small parts every workshop page shares: the item's square, the capsule at
// the end of a row, and the quiet line that says something went wrong without
// taking the page over.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/workshop_dependencies.dart';
import '../../workshop/workshop_models.dart';
import '../common/haptics.dart';
import '../kit/kit.dart';
import '../kit/kit_list.dart';
import '../plugins/list_chrome.dart';
import '../plugins/plugin_widgets.dart' show PluginAvatar;
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'workshop_text.dart';

/// The item's square, app-store style, for when there is no picture: the
/// title's first letter on a tint the item keeps.
class WorkshopAvatar extends StatelessWidget {
  const WorkshopAvatar(this.metadata, {super.key, this.size = 40});

  final WorkshopMetadata metadata;
  final double size;

  @override
  Widget build(BuildContext context) => PluginAvatar(
    name: metadata.identity,
    title: workshopTitleOf(metadata, Localizations.localeOf(context).languageCode),
    size: size,
  );
}

/// Where [entry]'s public picture is, or null when it has none (or the
/// workshop is not ready to say). The address is the data layer's: the same
/// origin the package itself is fetched from, never one a page puts together.
Uri? workshopPreviewUri(WidgetRef ref, WorkshopEntry entry) {
  if (entry.preview == null) return null;
  return switch (ref.watch(workshopClientProvider)) {
    AsyncData(:final value) => value.publicPreviewUri(entry),
    _ => null,
  };
}

/// The picture itself. Pixel pets are drawn with hard edges; a companion's
/// cover is smoothed. While it loads, and if it cannot be had, [fallback]
/// stays: a missing picture says nothing about the package.
class WorkshopPreviewImage extends StatelessWidget {
  const WorkshopPreviewImage({
    super.key,
    required this.uri,
    required this.kind,
    required this.fallback,
    this.fit = BoxFit.contain,
    this.cacheExtent,
  });

  final Uri uri;
  final String kind;
  final Widget fallback;
  final BoxFit fit;

  /// The longest side to decode to, in physical pixels. Not used for pixel
  /// pets: resampling would blur them.
  final int? cacheExtent;

  @override
  Widget build(BuildContext context) {
    final pixel = kind == 'pet';
    return Image.network(
      uri.toString(),
      fit: fit,
      filterQuality: pixel ? FilterQuality.none : FilterQuality.medium,
      cacheWidth: pixel ? null : cacheExtent,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, synchronous) => frame == null && !synchronous ? fallback : child,
      errorBuilder: (context, error, stack) => fallback,
    );
  }
}

/// The item's square with its public picture when the workshop has one for
/// this release, and the letter square otherwise.
class WorkshopEntryAvatar extends ConsumerWidget {
  const WorkshopEntryAvatar(this.entry, {super.key, this.size = 40});

  final WorkshopEntry entry;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letter = WorkshopAvatar(entry.metadata, size: size);
    final uri = workshopPreviewUri(ref, entry);
    if (uri == null) return letter;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: scheme.onSurface.withValues(alpha: 0.05),
          shape: Squircle.border(size * 0.25),
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: Squircle.border(size * 0.25)),
          child: WorkshopPreviewImage(
            uri: uri,
            kind: entry.metadata.kind,
            fallback: letter,
            fit: entry.metadata.kind == 'pet' ? BoxFit.contain : BoxFit.cover,
            cacheExtent: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
          ),
        ),
      ),
    );
  }
}

/// The picture at a size it can be judged by, in the item's detail. Nothing
/// at all when the release has no picture or it cannot be shown.
class WorkshopPreviewPanel extends ConsumerWidget {
  const WorkshopPreviewPanel(this.entry, {super.key, this.height = 176});

  final WorkshopEntry entry;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = workshopPreviewUri(ref, entry);
    if (uri == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: scheme.onSurface.withValues(alpha: 0.04),
            shape: Squircle.border(AppShape.radiusLg.topLeft.x),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: WorkshopPreviewImage(
              uri: uri,
              kind: entry.metadata.kind,
              // Not an empty frame: the same square the list shows, larger.
              fallback: Center(child: WorkshopAvatar(entry.metadata, size: 72)),
              cacheExtent: (height * MediaQuery.devicePixelRatioOf(context)).ceil(),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the capsule at the end of a row offers.
enum WorkshopGetState { get, update, installed, running }

/// 获取 / 更新 / 已安装，或一枚 **16px 的进度环**（正在装）。每个状态都打开详情页；
/// 安装本身也从详情页走。
///
/// 皮肤走 `KitButton` 的 `field` 变体（规格 theme-ui §4.2：行里的右控件是
/// `bg-muted` + 12px 字 + 32 高；行本身才是可点的对象，控件不该抬成主操作）。
///
/// 进度环自己画：KitButton 只有图标位，放不下一个"直径固定、线宽固定"的环。
/// 环的直径 16 是这条规格里"装得下、又比 12 的图标位不显小"的那一档；比它更小
/// 在 32 高的按钮里会读成一个点，看不出是在转。
class WorkshopGetButton extends StatefulWidget {
  const WorkshopGetButton({super.key, required this.state, this.onPressed});

  final WorkshopGetState state;
  final VoidCallback? onPressed;

  @override
  State<WorkshopGetButton> createState() => _WorkshopGetButtonState();
}

class _WorkshopGetButtonState extends State<WorkshopGetButton> {
  /// 装完的那一下：进度环**原地**变成"已安装"，同时给一次 `mediumImpact`。
  ///
  /// 只认 running → installed 这一步。列表刷新、别的作品装完、页面重进都会让
  /// 这里重新 build，但只有"刚刚这枚环自己在转、现在转完了"才该震——触感是
  /// 信号，不是背景音。
  @override
  void didUpdateWidget(WorkshopGetButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state == WorkshopGetState.running && widget.state == WorkshopGetState.installed) {
      // 触感只走 `Haptics.commit()` 这一个出口（它内部就是 mediumImpact）：
      // 各处直接调 HapticFeedback 会让同一件事在不同页面震得不一样。
      Haptics.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final label = switch (state) {
      WorkshopGetState.get => l10n.workshopGet,
      WorkshopGetState.update => l10n.commonUpdate,
      WorkshopGetState.installed => l10n.commonInstalled,
      WorkshopGetState.running => l10n.pluginsInstalling,
    };
    // 固定这一格 84×32 并靠右对齐：三种文字的胶囊宽度不同，不锁住的话
    // 卡片的右缘会跟着状态一格一格地挪。84 是英文最长的一档（"Installing"）
    // 加内距之后还要留一点余量的宽度。
    return SizedBox(
      width: 84,
      height: Kit.hMd,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: AnimatedSwitcher(
          duration: KitMotion.of(context, AppMotion.quick),
          switchInCurve: AppMotion.swift,
          switchOutCurve: AppMotion.exit,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(animation), child: child),
          ),
          child: state == WorkshopGetState.running
              ? Semantics(
                  key: const ValueKey('workshop-get-running'),
                  label: label,
                  child: Container(
                    width: 60,
                    height: Kit.hMd,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(Kit.radiusControl),
                    ),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          strokeCap: StrokeCap.round,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                )
              : KitButton(
                  key: ValueKey('workshop-get-${state.name}'),
                  label: label,
                  variant: KitButtonVariant.field,
                  // 已安装是"没有动作"的那一档：禁用态降 50%（KitButton 的规矩），
                  // 不加一个"不可装"的中间色。
                  enabled: state != WorkshopGetState.installed && widget.onPressed != null,
                  onTap: widget.onPressed,
                ),
        ),
      ),
    );
  }
}

/// 一张作品卡：方块 · 标题 13.5/600 · 一行作者/类型 12/70% · 描述 12/70%（最多
/// 两行）· 标签行（[KitChip]）· 右下角元信息 11/60%。
///
/// 为什么是卡而不是分组卡里的一行：作品是有"封面感"的东西（看图、看作者、
/// 看标签），一行 44 高的密行放不下这四层信息；而分组卡是为了让一串**同质**
/// 的条目读起来像一张表，作品恰恰不是同质的。卡与卡之间 12、组与组之间 24，
/// 节奏由调用方给（[margin]）。
class WorkshopCard extends StatelessWidget {
  const WorkshopCard({
    super.key,
    required this.avatar,
    required this.title,
    this.line,
    this.lineColor,
    this.description,
    this.chips = const <Widget>[],
    this.meta,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final Widget avatar;
  final String title;

  /// 标题下面那一行：作者、类型、状态。
  final String? line;

  /// 那一行的颜色；不传就按 12/70% 的二级文字。失败状态才换色（不染标题）。
  final Color? lineColor;

  /// 描述，最多两行。空串按"没有"处理（不编一句来填空）。
  final String? description;

  /// 标签行。放不下时末尾渐隐（见 [ChipRowFade]）。
  final List<Widget> chips;

  /// 右下角元信息（版本、大小）。没有就不画。
  final String? meta;

  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry margin;

  /// 标题 13.5/600 / 说明 12/70% / 元信息 11/60%：卡的三层文字。
  ///
  /// 三档都转调 [list_chrome] 里那一份公共实现——工坊、插件、酒馆、文件四处
  /// 的卡必须长得一样，各写一份就会各自漂。
  static TextStyle titleStyle(BuildContext context) => cardTitleStyle(Theme.of(context));

  static TextStyle noteStyle(BuildContext context) => cardNoteStyle(context);

  static TextStyle metaStyle(BuildContext context) => cardMetaStyle(context);

  @override
  Widget build(BuildContext context) {
    final description = this.description?.trim() ?? '';
    final line = this.line?.trim() ?? '';
    final meta = this.meta?.trim() ?? '';
    final trailing = this.trailing;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle(context)),
                  if (line.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: lineColor == null ? noteStyle(context) : noteStyle(context).copyWith(color: lineColor),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing],
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: noteStyle(context)),
        ],
        if (chips.isNotEmpty || meta.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: ChipRowFade(chips: chips)),
              if (meta.isNotEmpty) ...[const SizedBox(width: 8), Text(meta, style: metaStyle(context))],
            ],
          ),
        ],
      ],
    );
    // 长按抬升 2px：卡片按住时离桌面远一点，松手回弹（[PressLift]）。
    return PressLift(
      child: KitItemCard(margin: margin, onTap: onTap, onLongPress: onLongPress, child: body),
    );
  }
}

/// 组标题：15/600 + 右侧计数 12/60%（计数变化时滚一次，见 [RollingCount]）。
class WorkshopGroupHeader extends StatelessWidget {
  const WorkshopGroupHeader({super.key, required this.title, required this.count, this.trailing});

  final String title;
  final int count;

  /// 右侧计数后面可能还有一个动作（例如「全部」）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: KitSectionHeader.titleStyle(context))),
          ),
          ?trailing,
          RollingCount(count, format: l10n.commonItemCount),
        ],
      ),
    );
  }
}

/// 作品的标签行：类型一枚（强调色），作者写的标签各一枚（中性色）。
///
/// 作者标签是**真的**由作者填的（`metadata.tags`），不是这里推出来的分类；
/// 最多两枚，再多会把卡片的第二行撑成第三种层次。
List<Widget> workshopTagChips(BuildContext context, WorkshopMetadata metadata, {int tags = 2}) {
  final scheme = Theme.of(context).colorScheme;
  return [
    KitChip(label: workshopKindText(context.l10n, metadata.kind)),
    for (final tag in metadata.tags.take(tags)) KitChip(label: tag, color: scheme.onSurfaceVariant),
  ];
}

/// How loud a [WorkshopNote] is.
enum WorkshopNoteTone { quiet, warning, danger }

/// One or two lines beside a small mark: a refresh that failed, a version
/// that was withdrawn. It sits in the page's flow and leaves the content up.
class WorkshopNote extends StatelessWidget {
  const WorkshopNote(
    this.text, {
    super.key,
    this.tone = WorkshopNoteTone.quiet,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 16, 12),
  });

  final String text;
  final WorkshopNoteTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    final color = switch (tone) {
      WorkshopNoteTone.quiet => colors.textTertiary,
      WorkshopNoteTone.warning => colors.warning,
      WorkshopNoteTone.danger => colors.danger,
    };
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(tone == WorkshopNoteTone.quiet ? AppIcons.info : AppIcons.warning, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tone == WorkshopNoteTone.quiet ? colors.textTertiary : theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 4),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(44, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
