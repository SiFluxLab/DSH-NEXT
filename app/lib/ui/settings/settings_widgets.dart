// SPDX-FileCopyrightText: 2026 CikeSeven
// SPDX-License-Identifier: MIT
// See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../common/list_page_row.dart' show ListPageRow;
import '../common/overview_card.dart' show OverviewChevron;
import '../common/segmented_pill.dart';
import '../kit/kit.dart';
import '../theme/theme.dart';
import 'index/spot_anchor.dart';
import 'index/spots.dart';
import 'settings_polish.dart';

export '../common/segmented_pill.dart' show PillSegment, SegmentedPill;
export 'index/spot_anchor.dart' show SpotAnchor, SpotKey;
export 'index/spots.dart' show SettingSpot, SettingsIndex, SettingsPageId, Spots;
export 'settings_polish.dart'
    show
        FadingHint,
        HitText,
        SettingsChoice,
        SettingsDangerSheet,
        SettingsLoss,
        SettingsValueText,
        confirmSettingsDanger,
        copySettingsValue,
        settingsRowOrigin,
        showSettingsPicker,
        showSettingsNotice;

/// Page-level group spacing: groups sit [SettingsMetrics.grid] (24) apart and
/// the cards sit on the page's 16 gutter.
///
/// 为什么是 16 而不是 20:这一页顶上第一件东西是搜索胶囊(16),第二件是账号
/// 概览卡(16),分组卡却是 20 —— 竖着扫一眼就能看见那 4px 的锯齿。留白该慷慨,
/// 但**同一列里只允许一条竖线**;所以分组卡回到 16,和胶囊、概览卡、二级页的
/// `ListPageCard` 站在同一条线上。分组之间 24(`mb-6`):一眼能分清"换组了",
/// 又不会让人以为翻到了另一页。
const kSettingsGroupMargin = EdgeInsets.fromLTRB(16, 0, 16, 24);

/// The measured geometry every settings-style row shares. Change it here and in
/// `test/settings/settings_geometry_test.dart` together.
///
/// ```
/// |16| (32) |12| 标题 / 副标题 …… 值 |16|
/// |16| (32) |12| 标题 …………………………  [ 开关轨道 ] |16|
/// |16| 标签 ………………………………………………………… 值 |16|
/// ```
///
/// **右缘只有一条**:值、开关轨道、箭头墨迹、分段胶囊的右端都停在离卡边
/// [inset] 的地方。以前值行留 12(照抄了箭头行的 12,而箭头自己还要往右挪
/// 3),于是一列值比下面一列开关多出 4px —— 单看没问题,一屏并列就是"没对齐"。
/// 需要 12 的只有"最后是箭头"的行,理由在 [trailingPad]。
///
/// **24 网格**:卡在 16,组标题在 16 + 8 = 24,行内的图标位从 16 起、宽 32、
/// 到 48(2×24),标题从 60 起 —— 竖线落在 24 的倍数上,横线落在 48 的两档
/// 行高上,整页才读得出一个网格。
abstract final class SettingsMetrics {
  /// Card edge → icon disc / plain label on the left, and → switch track,
  /// chevron ink, segmented pill or a bare value on the right.
  static const inset = 16.0;

  /// 网格:分组之间、组标题到卡、以及其他"看得出节奏"的间距都取它的倍数。
  static const grid = 24.0;

  /// 组标题 → 卡:半格(12),由 [KitSectionHeader] 自己的下留白给。
  static const titleGap = grid / 2;

  /// Right padding of a row ending in a chevron: the chevron is nudged out by
  /// [OverviewChevron.nudge] so its ink ends at [inset].
  ///
  /// 只有"最后是箭头"的行才用这个数;其它行(值、开关、任意控件)右缘都是
  /// [inset]。
  static const trailingPad = ListPageRow.trailingPad;

  /// Right padding of a row ending in a [KitSwitch].
  ///
  /// 开关自带 12 的外扩命中区（[KitSwitch.hitPadX]，那是布局的一部分），所以行
  /// 的右内边距要把它减掉，轨道才和同一张卡里的值、箭头停在同一竖线上。
  static const switchPad = inset - KitSwitch.hitPadX;
  static const icon = 32.0;
  static const iconGlyph = 18.0;

  /// Line icon on secondary pages (no tinted disc), centred in the [icon] slot.
  static const lineGlyph = 20.0;
  static const iconGap = 12.0;

  /// Where titles start in rows with an icon.
  static const textStart = inset + icon + iconGap;

  /// 44 / 56 两档行高只写在 [Kit] 一处：设置行和列表页的行本来就该一样高，
  /// 两处各写一份迟早会差开 2px。
  static const rowHeight = Kit.rowHeight;
  static const rowHeightTwoLine = Kit.rowHeightTwo;
}

/// 行标题：14 / 500。vetta 的列表是 `text-[13px]`、标题只多一个 `font-semibold`；
/// 手机上 13 偏小，这里取 14 并把字重降到 500，密度接近而可读性保住。
TextStyle? settingsTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14, height: 1.35, fontWeight: FontWeight.w500);

/// Round tinted icon for a settings row. [tint] picks one of the 8 fixed identity
/// pairs (pastel container + deep glyph). On hub pages every row of a group uses
/// the group's one tint.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, {super.key, this.tint = 0, this.danger = false});

  final IconData icon;
  final int tint;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = DshColors.of(context);
    final bg = danger ? colors.dangerContainer : colors.identity[tint % colors.identity.length];
    final fg = danger ? colors.onDangerContainer : colors.onIdentity[tint % colors.onIdentity.length];
    return DecoratedBox(
      decoration: ShapeDecoration(color: bg, shape: const CircleBorder()),
      child: SizedBox.square(
        dimension: SettingsMetrics.icon,
        child: Icon(icon, size: SettingsMetrics.iconGlyph, color: fg),
      ),
    );
  }
}

/// A 20dp line icon in the secondary colour, centred in the 32dp icon slot:
/// how rows on secondary pages show an icon.
class SettingsLineIcon extends StatelessWidget {
  const SettingsLineIcon(this.icon, {super.key, this.danger = false});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = DshColors.of(context);
    return SizedBox.square(
      dimension: SettingsMetrics.icon,
      child: Icon(
        icon,
        size: SettingsMetrics.lineGlyph,
        color: danger ? colors.danger : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// One row: icon · title (+ subtitle) · value · chevron/trailing.
///
/// Single-line rows are at least [SettingsMetrics.rowHeight] (44) tall, rows
/// with a subtitle [SettingsMetrics.rowHeightTwoLine] (56); the whole row is the
/// tap target (a soft highlight, no ripple).
///
/// 三件"小而必要"的事在这一层一次做完,二级页不必各写一遍:
/// - **右缘只一条**:值、开关轨道、箭头墨迹、任意控件都停在离卡边
///   [SettingsMetrics.inset] 处(箭头行除外,原因见 [SettingsMetrics.trailingPad]);
/// - **值先缩字号再省略**([SettingsValueText]):纯文字的值不会把行撑成两行,
///   也不会把标题挤成一两个字;
/// - **长按复制这一项的当前值**:值本来就是"这一项现在是什么",复制它比让用户
///   截图、手抄都省事;触感只给这一下(它是一次提交),底部一句「已复制」。
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    this.icon,
    this.title,
    this.spot,
    this.subtitle,
    this.subtitleWidget,
    this.value,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.tint = 0,
    this.danger = false,
    this.chevron,
    this.tinted = true,
    this.titleMaxLines,
    this.copyText,
  }) : assert(title != null || spot != null);

  /// Null for a plain row that lines up with [InfoRow]s.
  final IconData? icon;

  /// Defaults to [spot]'s title.
  final String? title;

  /// The row in the settings index: its anchor (key, search landing) and,
  /// unless [title] says otherwise, its title.
  final SettingSpot? spot;
  final String? subtitle;

  /// 代替 [subtitle] 的那一行。给 [FadingHint] 用:开关拨过去以后,说明**原地**
  /// 换成另一句话,而整行的高度不变。
  final Widget? subtitleWidget;

  /// Current value, right-aligned in the secondary colour.
  final Widget? value;

  /// Replaces the chevron (switches, spinners).
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 覆盖默认的长按(默认是"复制当前值",见类注释)。
  final VoidCallback? onLongPress;
  final int tint;
  final bool danger;

  /// Defaults to "has onTap and no trailing".
  final bool? chevron;

  /// False draws [icon] as a 20dp line icon ([SettingsLineIcon]) instead of a
  /// tinted disc: the default for rows on secondary pages.
  final bool tinted;

  /// Lines the title may take, cut with an ellipsis; null: as many as it needs.
  final int? titleMaxLines;

  /// 长按要复制的文字;省略时取 [value] 里的纯文字。
  final String? copyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = DshColors.of(context);
    final trailing = switch (this.trailing) {
      null => null,
      final KitSwitch toggle => toggle,
      // M3 开关自带 48 的点击区，放进行里要收掉；KitSwitch 的命中区长在它自己身上。
      final other => SwitchTheme(
        data: SwitchTheme.of(context).copyWith(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: other,
      ),
    };
    // 开关自带 12 的外扩命中区，行的右距要减掉它（见 [SettingsMetrics.switchPad]）。
    final switchRow = trailing is KitSwitch;
    final showChevron = chevron ?? (onTap != null && trailing == null);
    final icon = this.icon;
    final title = this.title ?? spot!.title(context.l10n);
    final subtitleWidget = this.subtitleWidget;
    final two = subtitleWidget != null || subtitle != null;
    // 长按复制:值行本来就有"这一项现在是什么"。值不是纯文字(状态胶囊、图标 +
    // 文字)时,调用方可以用 [copyText] 补一份可复制的文字。
    final copyable = copyText ?? (value is Text ? (value! as Text).data : null);
    final longPress =
        onLongPress ??
        (copyable == null || copyable.trim().isEmpty ? null : () => copySettingsValue(context, copyable));
    // 值先缩字号、再省略。只有纯文字的值得走这条阶梯;胶囊、图标 + 文字这类
    // 控件自己知道该多宽。
    Widget valueWidget(Widget raw) => switch (raw) {
      final Text text when text.data != null => SettingsValueText(text.data!, style: text.style),
      _ => raw,
    };
    return anchorSpot(
      spot,
      InkWell(
        onTap: onTap,
        onLongPress: longPress,
        splashFactory: rowSplash(context),
        highlightColor: scheme.onSurface.withValues(alpha: 0.05),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: two ? SettingsMetrics.rowHeightTwoLine : SettingsMetrics.rowHeight),
          child: Padding(
            // 右缘:开关让出它自己的命中区;最后是箭头时按箭头的墨迹算;其余
            // 一律 [SettingsMetrics.inset] —— 值与控件因此共用同一条竖线。
            padding: EdgeInsets.fromLTRB(
              SettingsMetrics.inset,
              6,
              switchRow
                  ? SettingsMetrics.switchPad
                  : showChevron
                  ? SettingsMetrics.trailingPad
                  : SettingsMetrics.inset,
              6,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  tinted ? SettingsIcon(icon, tint: tint, danger: danger) : SettingsLineIcon(icon, danger: danger),
                  const SizedBox(width: SettingsMetrics.iconGap),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 危险项**只**给图标与标题上色:整行铺一层红底会让人以为
                      // 这一行已经被判了刑,而它其实只是一枚按钮。
                      Text(
                        title,
                        maxLines: titleMaxLines,
                        overflow: titleMaxLines == null ? null : TextOverflow.ellipsis,
                        style: settingsTitleStyle(context)?.copyWith(color: danger ? colors.danger : scheme.onSurface),
                      ),
                      if (subtitleWidget != null) ...[
                        const SizedBox(height: 2),
                        subtitleWidget,
                      ] else if (subtitle case final sub?) ...[
                        const SizedBox(height: 1),
                        Text(sub, style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
                      ],
                    ],
                  ),
                ),
                // 右侧控件整簇最多 384（`max-w-[min(100%,24rem)]`）：值再长也在
                // 这里换行，不会把左边的标题挤成一两个字。
                if (value != null || trailing != null || showChevron) ...[
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: Kit.controlMaxWidth),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (value case final raw?)
                          Flexible(
                            child: DefaultTextStyle.merge(
                              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                              child: valueWidget(raw),
                            ),
                          ),
                        if (trailing != null) ...[if (value != null) const SizedBox(width: 8), trailing],
                        if (showChevron) ...[
                          if (value != null || trailing != null) const SizedBox(width: 4),
                          const OverviewChevron(),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row with a switch; the whole row toggles.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    this.icon,
    this.title,
    this.spot,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.tint = 0,
    this.tinted = true,
  }) : assert(title != null || spot != null);

  final IconData? icon;

  /// Defaults to [spot]'s title.
  final String? title;
  final SettingSpot? spot;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final int tint;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final fluid = AppMotion.fluid(context);
    void change(bool next) {
      if (fluid) HapticFeedback.selectionClick();
      onChanged!(next);
    }

    return MergeSemantics(
      child: SettingsTile(
        icon: icon,
        title: title,
        spot: spot,
        subtitle: subtitle,
        tint: tint,
        tinted: tinted,
        onTap: onChanged == null ? null : () => change(!value),
        // 开关换成 vetta 的几何：18.4 × 32、滑块 16、命中区外扩。
        trailing: KitSwitch(value: value, onChanged: onChanged == null ? null : change),
      ),
    );
  }
}

/// Plain label/value row for read-only facts (about, diagnostics): the label
/// where a plain row's title starts, the value ending 16 from the card edge.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      // 只读的事实也能长按复制(版本号、ID、路径):这是"看一眼再用"的东西,
      // 手动抄一遍最容易错。和 [SettingsTile] 同一个入口、同一句「已复制」。
      onLongPress: value.trim().isEmpty ? null : () => copySettingsValue(context, value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SettingsMetrics.rowHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SettingsMetrics.inset, vertical: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(label, style: settingsTitleStyle(context)?.copyWith(color: scheme.onSurface)),
                const SizedBox(width: 16),
                // 值同样是"先缩字号、再省略"([SettingsValueText]):一条长版本号
                // 或一串 SHA 不该在这里换成两行,把标签挤成两个字。
                Expanded(
                  child: SettingsValueText(
                    value,
                    style: mono
                        ? AppType.monoLabel(color: scheme.onSurfaceVariant).copyWith(height: 1.6)
                        : AppType.tabular(theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A group of rows with a small, faint title above the card and an optional
/// one-line footnote under it (title → card 8, card → footnote 8, groups 24
/// apart). Titles and footnotes start 24 from the
/// screen edge, under the page's large title.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.title,
    this.note,
    required this.children,
    this.footer,
    this.margin = kSettingsGroupMargin,
    this.spot,
  });

  final String? title;

  /// 标题右侧的计数（`2/4`、`3 项`），与标题同一基线。
  ///
  /// vetta 的分区标题是"15/600 + 右侧计数"：数字在标题行内收口，就不用为了
  /// 一个数字再多加一行说明，也不占行的位置。
  final String? note;
  final List<Widget> children;

  /// The card as one place in the settings index (界面's 网页版): its rows
  /// light together, inside the card's rounded edge.
  final SettingSpot? spot;

  /// A short note under the card (secondary colour). Keep it to a sentence.
  final Widget? footer;
  final EdgeInsetsGeometry margin;

  /// Style of section titles, for places that draw one without a card.
  static TextStyle? titleStyle(BuildContext context) => KitSectionHeader.titleStyle(context);

  /// Space between the card and its [footer].
  static const footerGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = KitRowList(children: children);
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title case final title?)
            // 组标题落在 24 的竖线上(卡 16 + 8):和 `ListPageCard`、
            // `SheetGroup` 的组标题同一个左缘。KitSectionHeader 自己还带 2,
            // 所以这里补 6,加起来正好 8。
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Semantics(
                header: true,
                child: KitSectionHeader(title: title, note: note),
              ),
            ),
          // 分区卡：实色面 + 实线边框 + 圆角 12（vetta 的 `rounded-xl border border-border bg-card`）。
          // 行与行之间是一条 0.5px 细线（[KitRowList]），不再是 2px 的"缝"——缝会读出
          // "一堆小卡片"，细线才读作"一张卡里的多行"。
          KitCard(child: spot == null ? rows : SpotAnchor(spot: spot!, child: rows)),
          if (footer case final footer?)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, footerGap, 8, 0),
              child: DefaultTextStyle.merge(
                style: theme.textTheme.bodySmall?.copyWith(color: DshColors.of(context).textTertiary, height: 1.55),
                child: footer,
              ),
            ),
        ],
      ),
    );
  }
}

/// A title with its value at the right, the slider under it, the track running from the title's
/// edge to the value's (16 from the card on both sides, as a switch track ends). Neutral, like
/// every slider in settings: the page's accent stays with the switches.
///
/// ```
/// |16| 模糊 …………………………………………………… 30% |16|
/// |16| ━━━━━━━━━●──────────────────────── |16|
/// ```
///
/// [value] is 0–1 and lands on [steps] even steps (no tick marks: the track stays one quiet
/// line); [label] reads a value, a percent unless told otherwise. [onChanged] follows the
/// finger, [onChangeEnd] is the value let go on.
///
/// 小巧思:**标题那一行可以左右滑**,每滑过 24dp 走一格并「嗒」一声(极轻的刻度
/// 触感)。讨喜在哪:滑杆的拇指只有 20 宽,想从 30% 挪到 35% 常常要来回蹭;滑
/// 整个标题行则是指哪走哪,还不用瞄准。手势只挂在标题行上,滑杆自己的拖动一点
/// 不受影响(两者不在同一个手势区里,不会抢)。
class SettingsSliderTile extends StatefulWidget {
  const SettingsSliderTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.steps = defaultSteps,
    this.label = percent,
  });

  final String title;

  /// 0–1.
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final int steps;
  final String Function(double value) label;

  /// 5% steps.
  static const defaultSteps = 20;

  /// `0.3` as `30%`.
  static String percent(double v) => '${(v * 100).round()}%';

  /// 滑过多少像素算一格。
  static const stepPixels = 24.0;

  @override
  State<SettingsSliderTile> createState() => _SettingsSliderTileState();
}

class _SettingsSliderTileState extends State<SettingsSliderTile> {
  /// 一次滑动里最后落到的值:松手(或手势被取消)时交给 [SettingsSliderTile.onChangeEnd]。
  double? _stepped;

  double _snap(double v) => (v * widget.steps).round() / widget.steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = widget.value.clamp(0.0, 1.0);
    final step = 1 / widget.steps;
    // 一格 +1:到顶到不了就什么都不做(不夹到 1 再"确认"一次没变的值)。
    void stepBy(bool forward) {
      final next = (_snap(v) + (forward ? step : -step)).clamp(0.0, 1.0);
      final landed = _snap(next);
      if (landed == _snap(v)) return;
      _stepped = landed;
      HapticFeedback.selectionClick();
      widget.onChanged(landed);
    }

    void settle() {
      final last = _stepped;
      if (last == null) return;
      _stepped = null;
      widget.onChangeEnd(last);
    }

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(SettingsMetrics.inset, 14, SettingsMetrics.inset, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: _StepDrag(
                stepPixels: SettingsSliderTile.stepPixels,
                onStep: stepBy,
                onEnd: settle,
                child: Row(
                  children: [
                    Expanded(child: Text(widget.title, style: settingsTitleStyle(context))),
                    const SizedBox(width: 12),
                    // 值走等宽数字:31% → 36% 时不该左右抖一下。
                    Text(
                      widget.label(v),
                      style: AppType.tabular(theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              label: widget.title,
              child: Slider(
                value: v,
                // No inset for the thumb's halo: the track ends where the text does.
                padding: EdgeInsets.zero,
                activeColor: scheme.onSurfaceVariant,
                inactiveColor: scheme.onSurface.withValues(alpha: 0.1),
                // What the value is, not the step it would land on: a saved 37% reads 37%.
                semanticFormatterCallback: widget.label,
                onChanged: (raw) {
                  final next = _snap(raw);
                  if (next == _snap(v)) return;
                  HapticFeedback.selectionClick();
                  widget.onChanged(next);
                },
                onChangeEnd: (raw) => widget.onChangeEnd(_snap(raw)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 横向拖动按格计步:每走 [stepPixels] 记一格,方向按书写方向算(RTL 里往右是
/// 减)。它只包住标题行,不吃滑杆的手势。
class _StepDrag extends StatefulWidget {
  const _StepDrag({required this.stepPixels, required this.onStep, required this.onEnd, required this.child});

  final double stepPixels;

  /// true = 往"更大"的方向走一格。
  final ValueChanged<bool> onStep;
  final VoidCallback onEnd;
  final Widget child;

  @override
  State<_StepDrag> createState() => _StepDragState();
}

class _StepDragState extends State<_StepDrag> {
  /// 还没走满一格的余量;一次手势结束就归零。
  double _carry = 0;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _carry = 0,
      onHorizontalDragUpdate: (details) {
        _carry += details.delta.dx * (rtl ? -1 : 1);
        while (_carry.abs() >= widget.stepPixels) {
          final forward = _carry > 0;
          _carry += forward ? -widget.stepPixels : widget.stepPixels;
          widget.onStep(forward);
        }
      },
      onHorizontalDragEnd: (_) {
        _carry = 0;
        widget.onEnd();
      },
      onHorizontalDragCancel: () {
        _carry = 0;
        widget.onEnd();
      },
      child: widget.child,
    );
  }
}

/// 设置里的分段选择行(主题、字号这类二到四选一):放得下就和标题排一行、
/// 控件靠右;放不下(窄屏、系统大字号)就把控件放到标题下面整行显示,
/// 选项不会被挤成竖排。左右内边距与 [SettingsTile] 相同,胶囊右缘与开关轨道对齐。
class SettingsSegmentTile<T> extends StatelessWidget {
  const SettingsSegmentTile({
    super.key,
    this.icon,
    this.tint = 0,
    this.title,
    this.spot,
    this.subtitle,
    this.subtitleAction,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.onReselect,
    this.tinted = true,
  }) : assert(title != null || spot != null);

  final IconData? icon;
  final int tint;

  /// Defaults to [spot]'s title.
  final String? title;
  final SettingSpot? spot;

  /// A line under the control (so the control stays put when it comes and goes).
  final String? subtitle;

  /// Something to tap right after [subtitle]; on the next line when it doesn't fit.
  final Widget? subtitleAction;
  final List<PillSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;

  /// See [SegmentedPill.onReselect].
  final ValueChanged<T>? onReselect;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final titleStyle = settingsTitleStyle(context);
    final icon = this.icon;
    final title = this.title ?? spot!.title(context.l10n);
    const iconWidth = SettingsMetrics.icon + SettingsMetrics.iconGap;
    return anchorSpot(
      spot,
      Padding(
        padding: const EdgeInsets.fromLTRB(SettingsMetrics.inset, 8, SettingsMetrics.inset, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pillWidth = SegmentedPill.naturalWidth(context, [for (final s in segments) s.label]);
            final titlePainter = TextPainter(
              text: TextSpan(text: title, style: titleStyle),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
              textDirection: TextDirection.ltr,
            )..layout();
            final titleWidth = titlePainter.width;
            titlePainter.dispose();
            final lead = icon == null ? 0.0 : iconWidth;
            final inline = lead + titleWidth + 16 + pillWidth <= constraints.maxWidth;
            final heading = [
              if (icon != null) ...[
                tinted ? SettingsIcon(icon, tint: tint) : SettingsLineIcon(icon),
                const SizedBox(width: SettingsMetrics.iconGap),
              ],
            ];
            final pill = SegmentedPill<T>(
              segments: segments,
              selected: selected,
              onChanged: onChanged,
              onReselect: onReselect,
              expand: !inline,
            );
            final note = switch (subtitle) {
              final sub? => Padding(
                padding: EdgeInsets.only(left: lead, top: 6, bottom: 2),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      sub,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DshColors.of(context).textTertiary),
                    ),
                    ?subtitleAction,
                  ],
                ),
              ),
              null => null,
            };
            if (inline) {
              final row = ConstrainedBox(
                constraints: const BoxConstraints(minHeight: SettingsMetrics.rowHeight - 16),
                child: Row(
                  children: [
                    ...heading,
                    Text(title, style: titleStyle),
                    const Spacer(),
                    pill,
                  ],
                ),
              );
              if (note == null) return row;
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [row, note]);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: SettingsMetrics.icon),
                  child: Row(
                    children: [
                      ...heading,
                      Expanded(child: Text(title, style: titleStyle)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.only(left: lead),
                  child: pill,
                ),
                const SizedBox(height: 4),
                ?note,
              ],
            );
          },
        ),
      ),
    );
  }
}
