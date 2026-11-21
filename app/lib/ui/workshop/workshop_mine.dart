// 「我的投稿」: what this GitHub account sent to the workshop, each with its
// review status, and the way in to 投稿 (docs/design/workshop-app.md).
//
// Every row comes from workshopSubmissionsProvider, which starts over when
// the account or the workshop changes; nothing here keeps rows of its own, so
// one account's submissions are never drawn under another. Reading needs the
// GitHub sign-in and the credential agreement (workshop_mine_access.dart); it
// does not need uploads to be open.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/workshop_account_state.dart';
import '../../state/workshop_auth_state.dart';
import '../../state/workshop_submissions_state.dart';
import '../../workshop/workshop_models.dart';
import '../common/brief_notice.dart';
import '../common/capsule_chip.dart';
import '../common/empty_view.dart';
import '../common/fade_in.dart';
import '../common/status_chip.dart';
import '../kit/kit_list.dart';
import '../plugins/list_chrome.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'workshop_mine_access.dart';
import 'workshop_mine_sheet.dart';
import 'workshop_mine_text.dart';
import 'workshop_publish_page.dart';
import 'workshop_text.dart';
import 'workshop_widgets.dart';

/// Reads the person's submissions again (pull to refresh on the 我的投稿 tab).
/// Completes when the read settles; a failure stays in the controllers' state
/// and is shown in place.
Future<void> refreshWorkshopMine(WidgetRef ref) async {
  try {
    // The workshop's own checks come first: while they fail, nothing can be
    // read as this account.
    if (ref.read(workshopAccessProvider).error != null) {
      await ref.read(workshopAccessProvider.notifier).refresh();
    }
    final access = ref.read(workshopAccessProvider);
    final gate = workshopAuthorGate(access);
    final checking = gate == WorkshopAuthorGate.checking && access.signedIn;
    if (gate != WorkshopAuthorGate.open && !checking) return;
    // False (something else is running) needs no word here: that read
    // brings the list too.
    await ref.read(workshopSubmissionsProvider.notifier).refresh();
  } on Object {
    // The page left while this was waiting.
  }
}

/// The slivers of the 我的投稿 tab.
class WorkshopMineSliver extends ConsumerStatefulWidget {
  const WorkshopMineSliver({super.key});

  @override
  ConsumerState<WorkshopMineSliver> createState() => _WorkshopMineSliverState();
}

class _WorkshopMineSliverState extends ConsumerState<WorkshopMineSliver> {
  @override
  void initState() {
    super.initState();
    // Coming to the tab reads the list again (old rows stay up meanwhile).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(onlyFirst: false);
    });
  }

  /// Reads the first page if the account may. [onlyFirst]: not when this
  /// account's list is already here.
  void _load({required bool onlyFirst}) {
    final subs = ref.read(workshopSubmissionsProvider);
    if (!ref.read(workshopAccessProvider).canAuthenticate || subs.busy || onlyFirst && subs.hasLoaded) return;
    unawaited(ref.read(workshopSubmissionsProvider.notifier).refresh());
  }

  Future<void> _refresh() async {
    final accepted = await ref.read(workshopSubmissionsProvider.notifier).refresh();
    if (mounted && !accepted) showBriefNotice(context, context.l10n.workshopErrorBusy);
  }

  Future<void> _more() async {
    final accepted = await ref.read(workshopSubmissionsProvider.notifier).loadMore();
    if (!mounted || accepted) return;
    // Not taken: something else is running, or the last page just came.
    if (ref.read(workshopSubmissionsProvider).hasMore) showBriefNotice(context, context.l10n.workshopErrorBusy);
  }

  Future<void> _select(WorkshopSubmissionStatus? status) async {
    if (ref.read(workshopSubmissionsProvider).status == status) return;
    final accepted = await ref.read(workshopSubmissionsProvider.notifier).selectStatus(status);
    if (mounted && !accepted) showBriefNotice(context, context.l10n.workshopErrorBusy);
  }

  Future<void> _publish() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WorkshopPublishPage()));
    // Whatever happened there, read the list again.
    if (mounted) _load(onlyFirst: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final access = ref.watch(workshopAccessProvider);
    final subs = ref.watch(workshopSubmissionsProvider);
    // The gate opening (signed in, agreed) or a new account starts the read.
    ref.listen(workshopAccessProvider.select((a) => (a.session, a.canAuthenticate)), (_, now) {
      if (now.$2) _load(onlyFirst: true);
    });
    final gate = workshopAuthorGate(access);

    // Not this account's list yet: say what is missing. Signed out never
    // shows rows, whatever is in memory.
    if (gate == WorkshopAuthorGate.signIn || gate != WorkshopAuthorGate.open && !subs.hasLoaded) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: gate == WorkshopAuthorGate.checking ? 64 : 40),
          child: WorkshopAuthorGateView(
            signInTitle: l10n.workshopMineSignInTitle,
            signInMessage: l10n.workshopMineSignInMessage,
            consentMessage: l10n.workshopMineConsentMessage,
          ),
        ),
      );
    }

    final filtered = subs.status != null;
    // The first read of the whole list: one quiet ring, or why it failed.
    if (!subs.hasLoaded && !filtered) {
      if (subs.error case final error?) {
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EmptyView(
                  icon: AppIcons.offline,
                  title: l10n.workshopMineLoadFailed,
                  message: workshopExceptionText(l10n, error),
                  action: EmptyAction(
                    label: l10n.commonRetry,
                    onPressed: subs.busy ? null : () => unawaited(_refresh()),
                  ),
                ),
              ),
            ),
            // A list that won't load is no reason to be stuck in the account.
            const SliverToBoxAdapter(child: _AccountLine()),
          ],
        );
      }
      return const SliverToBoxAdapter(child: _Ring());
    }

    final uploadsOff = access.capabilities != null && !access.uploadsEnabled;
    final items = subs.items;
    // Nothing was ever sent in: the empty state carries 投稿 itself.
    final none = subs.hasLoaded && items.isEmpty && !filtered;

    return SliverMainAxisGroup(
      slivers: [
        if (!none) ...[
          SliverToBoxAdapter(
            child: uploadsOff
                ? WorkshopNote(l10n.workshopErrorUploadOff)
                : KitRowCard(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    children: [
                      KitRow(
                        leading: Icon(
                          AppIcons.add,
                          size: KitRow.iconSize,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        title: l10n.workshopMinePublish,
                        note: l10n.workshopMinePublishHint,
                        chevron: true,
                        onTap: () => unawaited(_publish()),
                      ),
                    ],
                  ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                children: [
                  for (final status in const <WorkshopSubmissionStatus?>[
                    null,
                    WorkshopSubmissionStatus.pending,
                    WorkshopSubmissionStatus.approved,
                    WorkshopSubmissionStatus.rejected,
                    WorkshopSubmissionStatus.withdrawn,
                    WorkshopSubmissionStatus.draft,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CapsuleChoiceChip(
                        label: status == null ? l10n.workshopKindAll : workshopStatusLabel(l10n, status),
                        selected: subs.status == status,
                        onSelected: () => unawaited(_select(status)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        // The workshop's checks failing doesn't take this account's rows away.
        if (access.error case final error? when gate == WorkshopAuthorGate.failed)
          SliverToBoxAdapter(
            child: WorkshopNote(
              workshopErrorLine(l10n, error.code),
              actionLabel: l10n.commonRetry,
              onAction: () => unawaited(ref.read(workshopAccessProvider.notifier).refresh()),
            ),
          ),
        if (subs.error case final error? when subs.hasLoaded)
          SliverToBoxAdapter(
            child: WorkshopNote(
              '${l10n.workshopMineStale} ${workshopExceptionText(l10n, error)}',
              actionLabel: l10n.commonRetry,
              onAction: subs.busy ? null : () => unawaited(_refresh()),
            ),
          ),
        if (!subs.hasLoaded)
          // A filter was just picked: its rows are on the way, or didn't come.
          SliverToBoxAdapter(
            child: switch (subs.error) {
              final error? => Padding(
                padding: const EdgeInsets.only(top: 24),
                child: EmptyView(
                  icon: AppIcons.offline,
                  title: l10n.workshopMineLoadFailed,
                  message: workshopExceptionText(l10n, error),
                  action: EmptyAction(
                    label: l10n.commonRetry,
                    onPressed: subs.busy ? null : () => unawaited(_refresh()),
                  ),
                ),
              ),
              null => const _Ring(top: 40),
            },
          )
        else if (items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: none ? 40 : 24),
              child: none
                  ? EmptyView(
                      icon: AppIcons.workshop,
                      title: l10n.workshopMineEmptyTitle,
                      message: uploadsOff ? l10n.workshopErrorUploadOff : l10n.workshopMineEmptyMessage,
                      action: uploadsOff
                          ? null
                          : EmptyAction(label: l10n.workshopMinePublish, onPressed: () => unawaited(_publish())),
                    )
                  : EmptyView(icon: AppIcons.search, title: l10n.workshopMineEmptyFiltered),
            ),
          )
        else ...[
          // 组标题 + 计数（计数变化时滚一次）。这里数的是**已经读到**的条目，
          // 翻页后继续往后加，不假装它是全部。
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              // 标题跟着筛选走（与上面那排胶囊同一句话），而不是重复页签名：
              // 列表里看到的是"待审核"，标题就写"待审核"。
              child: WorkshopGroupHeader(
                title: switch (subs.status) {
                  null => l10n.workshopKindAll,
                  final status => workshopStatusLabel(l10n, status),
                },
                count: items.length,
              ),
            ),
          ),
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              // 一条投稿一张卡，卡与卡之间 12。
              return FadeSlideIn(
                key: ValueKey(item.id),
                index: i,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: WorkshopSubmissionRow(
                    submission: item,
                    onTap: () => unawaited(showWorkshopSubmissionSheet(context, item, session: subs.session)),
                  ),
                ),
              );
            },
          ),
          if (subs.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: subs.operation == WorkshopSubmissionsOperation.more
                    // 翻页也在等，但等的还是卡片：两张骨架，列表不会因为
                    // "换成一个转圈"在这个高度上跳一下。
                    ? ListSkeleton(
                        rows: 2,
                        avatar: 40,
                        lines: 2,
                        trailing: 0,
                        label: l10n.remoteLoading,
                        padding: EdgeInsets.zero,
                      )
                    : Center(
                        child: TextButton(
                          onPressed: subs.busy ? null : () => unawaited(_more()),
                          child: Text(l10n.workshopMineLoadMore),
                        ),
                      ),
              ),
            ),
        ],
        const SliverToBoxAdapter(child: _AccountLine()),
      ],
    );
  }
}

/// Which GitHub account these submissions belong to, and 退出登录. Signing out
/// only forgets the token here; the note says where GitHub takes it back.
class _AccountLine extends ConsumerWidget {
  const _AccountLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final login = ref.watch(workshopAccountProvider.select((value) => value.login));
    if (login == null) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: DshColors.of(context).textTertiary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(l10n.workshopAccountLine(login), style: style, overflow: TextOverflow.ellipsis)),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(workshopAccountProvider.notifier).signOut();
                if (context.mounted) showBriefNotice(context, l10n.workshopAccountSignedOut);
              } on Object {
                if (context.mounted) showBriefNotice(context, l10n.workshopAccountSignOutFailed);
              }
            },
            child: Text(l10n.workshopAccountSignOut),
          ),
        ],
      ),
    );
  }
}

/// One submission: square · title 13.5/600 · kind · version · 状态标签
/// （审核状态仍然用 [StatusChip]：它带语气色，是"状态"不是"标签"）。
class WorkshopSubmissionRow extends StatelessWidget {
  const WorkshopSubmissionRow({super.key, required this.submission, this.onTap});

  final WorkshopSubmission submission;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meta = submission.metadata;
    return WorkshopCard(
      avatar: WorkshopAvatar(meta, size: 40),
      title: workshopTitleOf(meta, Localizations.localeOf(context).languageCode),
      line: '${workshopKindText(l10n, meta.kind)} · ${meta.version}',
      chips: workshopTagChips(context, meta),
      trailing: StatusChip(
        tone: workshopStatusTone(submission.status),
        label: workshopStatusLabel(l10n, submission.status),
      ),
      onTap: onTap,
    );
  }
}

/// The first read of the list: six cards' worth of placeholders.
class _Ring extends StatelessWidget {
  const _Ring({this.top = 64});

  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top),
    child: ListSkeleton(rows: 6, avatar: 40, lines: 2, trailing: 0, label: context.l10n.remoteLoading),
  );
}
