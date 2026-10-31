import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_controller.dart';
import '../l10n/app_localizations.dart';
import 'zed_home_common.dart';

/// The Old design (the phone's "Classic"), ported from FoxyVPN's
/// Android app: the traditional VPN-app layout — the state as a plain
/// headline, the connect core, the session's length, and divided rows
/// for the server, the accounts and the speed.
class ZedOldHome extends StatelessWidget {
  const ZedOldHome({
    super.key,
    required this.core,
    required this.settings,
    this.onOpenServers,
    this.onOpenAccounts,
  });

  final CoreController core;
  final AppSettings settings;
  final VoidCallback? onOpenServers;
  final VoidCallback? onOpenAccounts;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = core.status!;
    final d = ZedHomeData(core, status, l,
        animationsEnabled: settings.animationsEnabled);
    final title = d.live
        ? l.zedVpnOn
        : d.busy
        ? l.stateConnecting
        : l.zedVpnOff;
    final proxy = status.proxy;
    return ZedHomeScaffold(
      children: [
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          reverseDuration: const Duration(milliseconds: 150),
          child: Text(
            title,
            key: ValueKey(title),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: d.live ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: ZedConnectCore(
            live: d.live,
            busy: d.busy,
            since: d.since,
            size: 208,
            animationsEnabled: d.animationsEnabled,
            onToggle: () => d.toggle(context, onOpenAccounts),
          ),
        ),
        if (d.live) ...[
          const SizedBox(height: 10),
          Center(
            child: ZedElapsedText(
              since: d.since,
              prefix: '${l.zedConnectedFor} ',
              style: theme.textTheme.bodyMedium,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (d.hasError) ...[
          ZedErrorCard(text: d.errorText),
          const SizedBox(height: 12),
        ],
        _ClassicRow(
          title: l.navServers,
          subtitle: d.live
              ? [
                  d.place.name,
                  if (proxy != null && proxy.cityName.isNotEmpty)
                    proxy.cityName,
                ].join(' · ')
              : l.zedRecommendedTapChoose,
          onTap: () => onOpenServers?.call(),
        ),
        Divider(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        _ClassicRow(
          title: l.navAccounts,
          subtitle: l.zedAccountsOfConnected(d.live ? d.ready : 0, d.total),
          onTap: () => d.openAccounts(context, onOpenAccounts),
        ),
        Divider(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        _ClassicRow(
          title: l.zedSpeed,
          subtitle: d.live ? l.zedSpeedLive : l.zedIdle,
          onTap: () {},
        ),
        const SizedBox(height: 16),
        ZedModeSection(data: d),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// One divided row of the Old design: a title, a subtitle, a chevron.
class _ClassicRow extends StatelessWidget {
  const _ClassicRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
