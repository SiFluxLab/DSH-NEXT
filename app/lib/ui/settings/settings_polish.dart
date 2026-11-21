// SPDX-FileCopyrightText: 2026 CikeSeven
// SPDX-License-Identifier: MIT
// See THIRD_PARTY_NOTICES.md.

// 设置页的"小巧思"都收在这里。
//
// 为什么单独一个文件而不是散回各页:这些细节——值文字先缩字号再省略、开关的
// 说明文字**原地**换文案、选择面板从被点的那一行长出来、危险确认把"将要失去
// 什么"排成具体清单——必须由设置首页和每一个二级页**共用同一份实现**。写两份
// 的那天起,同一枚开关在两页里就会有两种手感,而这正是"看起来不够精致"最常
// 见的来源。
//
// 依赖方向:这一层只依赖 kit / common 的公共件,不反向依赖
// settings_widgets.dart,免得两边的 import 绕成圈。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../common/app_sheet.dart';
import '../common/brief_notice.dart';
import '../common/list_page_row.dart';
import '../kit/kit.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';

/// 行右侧的值:**先缩字号,再省略**。
///
/// 为什么不是一上来就 `TextOverflow.ellipsis`:设置页里的"长值"几乎都是
/// 本来就该读全的东西(主机名、模型名、根地址)。14 号放不下退到 13、再退到
/// 12,12 还放不下才省略——多读两三个字,比让用户点进详情页再退回来便宜得多。
/// 同时它保证值永远只占一行:行高不会因为一个长主机名偷偷变成两行。
class SettingsValueText extends StatelessWidget {
  const SettingsValueText(this.text, {super.key, this.style, this.maxLines = 1});

  final String text;

  /// 覆盖继承来的样式(警告色、等宽这类)。阶梯的**起点**也跟着它走。
  final TextStyle? style;
  final int maxLines;

  /// 阶梯:14 → 13 → 12。12 是这套界面里最小的正文,再小就不该用来读长值。
  static const steps = <double>[14, 13, 12];

  @override
  Widget build(BuildContext context) {
    // 值的常规样式来自行里的 DefaultTextStyle.merge(次级文字色)。
    final inherited = DefaultTextStyle.of(context).style;
    final base = style == null ? inherited : inherited.merge(style);
    final start = base.fontSize ?? 14;
    final ladder = <double>{
      for (final size in steps)
        if (size <= start) size,
      start,
    }.toList()..sort((a, b) => b.compareTo(a));
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth.isFinite ? box.maxWidth : double.infinity;
        for (final size in ladder) {
          final candidate = base.copyWith(fontSize: size);
          final painter = TextPainter(
            text: TextSpan(text: text, style: candidate),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: maxLines,
            textDirection: Directionality.of(context),
          )..layout(maxWidth: width);
          final fits = !painter.didExceedMaxLines;
          painter.dispose();
          if (fits) return _line(candidate);
        }
        // 最小的字号也放不下:这时才省略,并且省略在最左边读不到的部分。
        return _line(base.copyWith(fontSize: math.min(start, steps.last)));
      },
    );
  }

  Widget _line(TextStyle style) =>
      Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: style);
}

/// 说明文字**原地**换文案:120ms 淡入淡出,什么都不重排。
///
/// 讨喜在哪:开关拨过去以后,如果说明那一行跟着换行数或换高度,整张卡会
/// 往下"跳"一下——手指还在开关上,页面已经动了。这里把高度按**一行**钉死,
/// 新旧两句话在同一格里交叉淡变,读起来是"这句话改了",而不是"页面刷新了"。
class FadingHint extends StatelessWidget {
  const FadingHint(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  /// 120ms:比 [AppMotion.quick](160)还短一档——它换的是同一行的同一句话,
  /// 不需要"让人看清它从哪来"。
  static const duration = Duration(milliseconds: 120);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontSize: 12, height: 1.4, color: color ?? DshColors.of(context).textTertiary);
    // 一行的高度按当前文字缩放算死:两句文案长短不同也不会把行撑高 1px。
    final line = MediaQuery.textScalerOf(context).scale(12) * 1.4;
    return SizedBox(
      height: line.ceilToDouble(),
      child: AnimatedSwitcher(
        duration: KitMotion.of(context, duration),
        switchInCurve: AppMotion.swift,
        switchOutCurve: AppMotion.exit,
        // 左对齐叠放:旧句往新的方向淡出,不会因为长度不同左右乱跳。
        layoutBuilder: (current, previous) =>
            Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
        child: Text(text, key: ValueKey(text), maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ),
    );
  }
}

/// 搜索结果的标题:把命中的那几个字标出来。
///
/// 只染色 + 加半档字重(w500 → w600),不换字号、不加底色:一行里只有这一处
/// 变化时,眼睛会先读到"你搜的就是这个",而不是"这里有个色块"。
///
/// 大小写与全角折叠都在查询侧做过([normalizeQuery]),原始标题里找不到字面
/// 命中时(比如用户打的是全角)就原样显示——宁可不高亮,也不要标错位置。
class HitText extends StatelessWidget {
  const HitText(this.text, {super.key, required this.query, this.style, this.suffix, this.maxLines = 1});

  final String text;
  final String query;
  final TextStyle? style;

  /// 标题后面跟的一小段(命中的同义词):三级色,先被省略号吃掉。
  final String? suffix;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    final at = q.isEmpty ? -1 : text.toLowerCase().indexOf(q.toLowerCase());
    final suffix = this.suffix;
    final tail = [
      if (suffix != null && suffix.trim().isNotEmpty)
        TextSpan(
          text: ' · ${suffix.trim()}',
          style: TextStyle(color: DshColors.of(context).textTertiary, fontWeight: FontWeight.w400),
        ),
    ];
    if (at < 0) {
      if (tail.isEmpty) return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style);
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: text),
            ...tail,
          ],
        ),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final accent = Theme.of(context).colorScheme.primary;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: text.substring(at, at + q.length),
            style: TextStyle(color: accent, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: text.substring(at + q.length)),
          ...tail,
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// 选择面板里的一项。
@immutable
class SettingsChoice<T> {
  const SettingsChoice(this.value, this.title, {this.note});

  final T value;
  final String title;

  /// 第二行说明(这个选项是什么、什么时候用它)。
  final String? note;
}

/// 面板"长出"的那个点:传一行自己的 [BuildContext](在外面包一层 [Builder]
/// 或给它一枚 GlobalKey),取它的中心偏右——值、开关、箭头都停在右边,眼睛
/// 和手指也落在那儿,所以面板该从那里长出来。
///
/// 量不到(还没布局、被回收)时返回 null:调用方就不做"长出"这件事,只淡入。
Offset? settingsRowOrigin(BuildContext row) {
  final box = row.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  final topLeft = box.localToGlobal(Offset.zero);
  return Offset(topLeft.dx + box.size.width * 0.72, topLeft.dy + box.size.height / 2);
}

/// 打开一枚选择面板:它从 [origin] 长出来,收起时缩回那里。
///
/// 为什么不是普通底部弹层:底部弹层从屏幕底边升起,和"我刚点的是第三行"没有
/// 关系;从行里长出来的面板把"面板属于这一行"讲清楚了——点在哪,它就从哪
/// 展开,收回去也回到同一个点。动效 300ms、带轻微过冲([_growCurve]),
/// 系统要求减少动画时长度为 0。
Future<T?> showSettingsPicker<T>(
  BuildContext context, {
  required String title,
  required List<SettingsChoice<T>> choices,
  required T selected,
  Offset? origin,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // 比弹层浅的幕:面板本身不大,不该把整页压黑。
    barrierColor: Colors.black.withValues(alpha: 0.18),
    transitionDuration: KitMotion.of(context, AppMotion.page),
    pageBuilder: (dialogContext, routeAnimation, secondaryAnimation) =>
        _PickerPanel<T>(title: title, choices: choices, selected: selected),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        _GrowFromOrigin(animation: animation, origin: origin, child: child),
  );
}

/// 与 [KitDualToggle.curve] 同一条:回弹只给"看得见的位移与缩放"。
const _growCurve = Cubic(0.34, 1.24, 0.64, 1);

/// 面板本体:底对齐的一张卡 + 一枚组标题,行就是普通的 [ListPageRow]。
class _PickerPanel<T> extends StatelessWidget {
  const _PickerPanel({required this.title, required this.choices, required this.selected});

  final String title;
  final List<SettingsChoice<T>> choices;
  final T selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // `showGeneralDialog` 不像 `showDialog` 那样在内容外面包一层 Dialog/Material:
    // 组标题与行里的文字都要一层 `DefaultTextStyle` 才排得出来(否则 debug 下直接
    // 断言)。一层透明 Material 顺手也把水波的宿主备好了。
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListPageCard(
              title: title,
              margin: EdgeInsets.zero,
              children: [
                for (final choice in choices)
                  Semantics(
                    selected: choice.value == selected,
                    child: ListPageRow(
                      title: choice.title,
                      subtitle: choice.note,
                      chevron: false,
                      trailing: choice.value == selected ? Icon(AppIcons.done, size: 18, color: scheme.primary) : null,
                      onTap: () => Navigator.of(context).pop(choice.value),
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

/// 缩放 + 平移,把面板"从 [origin] 长出来"。
///
/// 支点取整页(也就是面板所在的那个盒子)的**底边中点**,再把支点平移到
/// origin:点是跟着位移走的,所以「缩到最小的那一刻正好落在点击处」这件事
/// 对任何高度的面板都成立——不需要先把面板量一遍。收起时路由反向播放,
/// 同一个公式把它缩回同一个点。
class _GrowFromOrigin extends StatelessWidget {
  const _GrowFromOrigin({required this.animation, required this.origin, required this.child});

  final Animation<double> animation;
  final Offset? origin;
  final Widget child;

  /// 起点大小:0.55 刚好让人看出"它就是那一行变出来的",又不至于小成一粒。
  static const from = 0.55;

  @override
  Widget build(BuildContext context) {
    final source = origin;
    if (source == null) return child;
    if (AppMotion.reduced(context)) return child;
    return LayoutBuilder(
      builder: (context, box) {
        final pivot = Offset(box.maxWidth / 2, box.maxHeight);
        return AnimatedBuilder(
          animation: animation,
          // 展开走 _growCurve（带轻微过冲），收回走弹层自己那条快出曲线。
          builder: (context, child) {
            final t = animation.status == AnimationStatus.reverse
                ? AppMotion.sheetFall.transform(animation.value)
                : _growCurve.transform(animation.value);
            final scale = from + (1 - from) * t;
            // 支点 s=0 时落在 origin:shift = (origin - pivot) × (1 - s)。
            final shift = (source - pivot) * (1 - scale);
            return Transform.translate(
              offset: shift,
              child: Transform.scale(scale: scale, alignment: Alignment.bottomCenter, child: child),
            );
          },
          child: child,
        );
      },
    );
  }
}

/// 危险操作将失去的一项(标签 + 那件事的**实际值**)。
@immutable
class SettingsLoss {
  const SettingsLoss(this.label, this.value);

  final String label;
  final String value;
}

/// 危险操作的二次确认:先把**具体清单**摆出来,再给一枚红色的主键。
///
/// 为什么值得多一面板:危险操作的犹豫都来自"我不知道会少掉什么"。只写一句
/// "此操作无法撤销"是把判断交回给用户;把"删掉的正是这一条、这条地址、这个
/// 默认"逐条列出来,用户不用猜,点下去也更放心。清单里的值取自当场的数据,
/// 不是编出来的说明。
///
/// 锁定式弹层([SheetDismissal.button]):拖动与点幕不会关掉它,只有右上角的
/// × 与系统返回表示"不"。每屏只有一个主要动作,就是那枚红键。
Future<bool> confirmSettingsDanger(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  List<SettingsLoss> lost = const [],
  List<SettingsLoss> kept = const [],
}) async {
  final choice = await showAppSheet<bool>(
    context,
    dismissal: SheetDismissal.button,
    isScrollControlled: true,
    builder: (_) => SettingsDangerSheet(title: title, body: body, action: action, lost: lost, kept: kept),
  );
  return choice ?? false;
}

/// [confirmSettingsDanger] 的弹层本体;pop true 表示"确认"。
class SettingsDangerSheet extends StatelessWidget {
  const SettingsDangerSheet({
    super.key,
    required this.title,
    required this.body,
    required this.action,
    this.lost = const [],
    this.kept = const [],
  });

  final String title;
  final String body;

  /// 主键上写的就是这件事本身(「删除服务」),不写「确定」。
  final String action;
  final List<SettingsLoss> lost;
  final List<SettingsLoss> kept;

  /// 主键高度(1× 文字时);字号变大时它跟着长。
  static const keyHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    final facts = [...lost, ...kept];
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 问题读全,不截断:危险确认里的标题被省略号吃掉是最糟的情况。
          SheetHeader(title, maxLines: null),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kSheetGutter),
                    child: Text(
                      body,
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (facts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(kSheetGutter, 16, kSheetGutter, 0),
                      // 清单本身是"内容",用平卡(实色面 + 0.5px 细线),不投影。
                      child: FlatPanel(
                        radius: AppShape.lg,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: KitRowList(
                            children: [
                              for (final item in lost) _LossRow(label: item.label, value: item.value, kept: false),
                              for (final item in kept) _LossRow(label: item.label, value: item.value, kept: true),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kSheetGutter, 20, kSheetGutter, 0),
            child: FilledButton(
              key: const ValueKey('settings-danger-confirm'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(keyHeight),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                backgroundColor: colors.danger,
                foregroundColor: colors.onDanger,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action, textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 清单里的一行:减号 = 会被删掉,对勾 = 会留下。
///
/// 用记号而不是再加两行小标题("会删除"/"会保留"):记号在同一列里对齐,
/// 读起来是一条清单,而不是两段各带标题的说明。
class _LossRow extends StatelessWidget {
  const _LossRow({required this.label, required this.value, required this.kept});

  final String label;
  final String value;
  final bool kept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = DshColors.of(context);
    final tone = kept ? colors.textTertiary : scheme.onSurface;
    final mark = kept
        ? Icon(AppIcons.done, size: 14, color: colors.success)
        : Container(
            width: 10,
            height: 1.5,
            decoration: BoxDecoration(color: colors.danger, borderRadius: BorderRadius.circular(1)),
          );
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            SizedBox(width: 16, child: Center(child: mark)),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w500, color: tone),
              ),
            ),
            const SizedBox(width: 12),
            // 值也走"先缩字号再省略":一条长地址不该把标签挤成两个字。
            Flexible(
              flex: 3,
              child: SettingsValueText(
                value,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: kept ? colors.textTertiary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 行内的"一句话提示"(复制成功这类)。Scaffold 不在时什么都不做。
void showSettingsNotice(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)?.showBriefNotice(text);
}

/// 「已复制」的口径:触感只给这种"提交类"动作,一句提示在底部一闪而过。
///
/// 长按任意带值的一行都走这里,所以文案与触感全 App 只有一份。
Future<void> copySettingsValue(BuildContext context, String text) async {
  if (text.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  HapticFeedback.mediumImpact();
  showSettingsNotice(context, context.l10n.commonCopied);
}
