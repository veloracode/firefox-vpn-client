import 'package:flutter/material.dart';

import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../platform.dart';
import 'accounts_page.dart' show accountReason;
import 'batch_import_dialog.dart';
import 'format.dart';
import 'signin_dialog.dart';
import 'widgets.dart';

/// The Foxy accounts page: the classic page's accounts as phone-style
/// cards, with the same actions (use now, refresh, remove, the on/off
/// switch), plus batch import. Every action is the core's, through the
/// controller; only the arrangement is FoxyVPN's.
class FoxyAccountsPage extends StatelessWidget {
  const FoxyAccountsPage({super.key, required this.core});

  final CoreController core;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final list = core.accounts?.accounts ?? const <Account>[];
    final threshold = core.accounts?.thresholdPercent ?? 0;
    return ListView(
      padding: pagePadding(context),
      children: [
        Row(
          children: [
            Expanded(child: PageTitle(l.navAccounts)),
            OutlinedButton.icon(
              onPressed: () => showBatchImportDialog(context, core),
              icon: const Icon(Icons.playlist_add_rounded),
              label: Text(l.batchImport),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => showSignInDialog(context, core),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.addAccount),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (core.accounts == null)
          const Center(child: CircularProgressIndicator())
        else if (list.isEmpty)
          Panel(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Icon(
                    Icons.group_add_outlined,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.noAccounts,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.noAccountsHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          )
        else
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _FoxyAccountCard(core: core, account: list[i], threshold: threshold),
          ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                [
                  l.accountsGuide(_allowance(list)),
                  if (list.length > 1) l.accountsOrderNote(threshold.round()),
                ].join(' '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.help_outline_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.createAccountTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.createAccountHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () => openUrl(firefoxAccountSignUpUrl),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(
                        'accounts.firefox.com',
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// An account's monthly allowance as the accounts report it (50 GB until
/// one has been read).
String _allowance(List<Account> list) {
  final limit =
      list
          .map((a) => a.usage?.limitBytes ?? 0)
          .where((b) => b > 0)
          .firstOrNull ??
      50 << 30;
  return formatBytes(limit).replaceAll('.0 ', ' ');
}

class _FoxyAccountCard extends StatelessWidget {
  const _FoxyAccountCard({
    required this.core,
    required this.account,
    required this.threshold,
  });

  final CoreController core;
  final Account account;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final a = account;
    final busy = core.busyAccounts.contains(a.id);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final usage = a.usage;
    return Opacity(
      opacity: a.enabled ? 1 : 0.6,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: a.active
              ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            a.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _pill(context, a),
                      ],
                    ),
                  ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    PopupMenuButton<String>(
                      tooltip: l.more,
                      onSelected: (v) => switch (v) {
                        'refresh' => runShowingErrors(
                          context,
                          () => core.refreshQuota(a),
                        ),
                        'remove' => _remove(context),
                        _ => null,
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'refresh',
                          child: ListTile(
                            leading: const Icon(Icons.sync_rounded),
                            title: Text(l.refreshQuota),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: ListTile(
                            leading: const Icon(
                              Icons.delete_outline_rounded,
                            ),
                            title: Text(l.remove),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (a.name != a.email && a.email.isNotEmpty)
                Text(a.email, style: muted),
              if (accountReason(l, a, threshold) case final reason?) ...[
                const SizedBox(height: 4),
                Text(reason, style: muted),
              ],
              const SizedBox(height: 12),
              if (usage == null)
                Text(l.quotaNotRead, style: muted)
              else if (usage.unlimited)
                Text(l.unlimitedQuota, style: muted)
              else ...[
                QuotaBar(percent: a.usedPercent, threshold: threshold),
                const SizedBox(height: 6),
                Text(
                  [
                    l.usedOf(
                      formatBytes(usage.usedBytes),
                      formatBytes(usage.limitBytes),
                    ),
                    if (usage.resetAt != null)
                      l.resets(formatDate(l, usage.resetAt!)),
                  ].join(' · '),
                  style: muted,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (a.needsSignIn)
                    FilledButton.tonal(
                      onPressed: busy ? null : () => _signInAgain(context),
                      child: Text(l.signInAgain),
                    )
                  else if (!a.active &&
                      a.enabled &&
                      a.status == AccountStatus.ready)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => runShowingErrors(
                              context,
                              () => core.activate(a),
                            ),
                      child: Text(l.useNow),
                    ),
                  const Spacer(),
                  Text(
                    a.enabled ? l.statusEnabled : l.statusDisabled,
                    style: muted,
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: a.enabled,
                    onChanged: busy
                        ? null
                        : (v) => runShowingErrors(
                            context,
                            () => core.setEnabled(a, v),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The account's state as a small label, as on the classic page.
  Widget _pill(BuildContext context, Account a) {
    final l = AppLocalizations.of(context);
    if (!a.enabled) return Pill(l.statusDisabled);
    if (a.active) {
      return Pill(
        l.statusActive,
        color: StatusColors.good,
        icon: Icons.bolt_rounded,
      );
    }
    return switch (a.status) {
      AccountStatus.ready => Pill(
        l.statusReady,
        color: Theme.of(context).colorScheme.primary,
      ),
      AccountStatus.reauthRequired => Pill(
        l.statusNeedsSignIn,
        color: StatusColors.bad,
      ),
      AccountStatus.reserved => Pill(
        l.statusReserved,
        color: StatusColors.busy,
      ),
      AccountStatus.unavailable => Pill(
        a.retryAt != null
            ? l.statusUnavailableUntil(formatDate(l, a.retryAt!))
            : l.statusUnavailable,
        color: StatusColors.busy,
      ),
      _ => Pill(a.status),
    };
  }

  /// Signs in with the stored password; without one, asks for it.
  Future<void> _signInAgain(BuildContext context) async {
    final api = core.api;
    if (api == null) return;
    try {
      final started = await api.startSignInAgain(account.id);
      if (context.mounted) {
        await showSignInDialog(context, core, started: started);
      }
    } on CoreApiException catch (e) {
      if (!context.mounted) return;
      if (e.statusCode == 409) {
        await showSignInDialog(context, core, email: account.email);
      } else {
        showError(context, e.message);
      }
    } on CoreUnavailable catch (e) {
      if (context.mounted) {
        showError(context, describeProblem(AppLocalizations.of(context), e));
      }
    }
  }

  Future<void> _remove(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.removeTitle),
        content: Text(l.removeBody(account.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StatusColors.bad),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.remove),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runShowingErrors(context, () => core.remove(account));
    }
  }
}
