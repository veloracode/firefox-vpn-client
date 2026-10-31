import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'connection_mode.dart';
import 'format.dart';
import 'signin_dialog.dart';
import 'widgets.dart';

/// The Foxy home: FoxyVPN's phone look on every screen — one big connect
/// button, the state under it, the account in use with its data bar, and
/// where the traffic goes. The classic home stays a design choice away
/// (Settings, Design). Every action is the core's, through the same
/// controller calls the classic home makes; nothing here decides anything
/// about the VPN itself.
class FoxyOverviewPage extends StatelessWidget {
  const FoxyOverviewPage({
    super.key,
    required this.core,
    required this.settings,
    this.onOpenServers,
    this.onOpenAccounts,
    this.onOpenConnection,
  });

  final CoreController core;
  final AppSettings settings;

  /// Opens the server list and the accounts (a page on the phone, a tab
  /// on the computer).
  final VoidCallback? onOpenServers;
  final VoidCallback? onOpenAccounts;

  /// Opens the connection settings, when Mozilla's servers are blocked.
  final VoidCallback? onOpenConnection;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = core.status!;
    final on = engineOn(status);
    final running = status.state.phase == Phase.running;
    // Connected only once a test confirms the connection, as on the
    // classic home; until then the state is Connecting.
    final connected = connectionLive(status, core.lastTest);
    final confirming = running && !connected;
    final look = PhaseLook.of(l, status);
    final accent = !on
        ? scheme.primary
        : connected
        ? StatusColors.good
        : status.state.phase == Phase.error
        ? StatusColors.bad
        : StatusColors.busy;
    final place = homeLocation(l, status, connected: connected);
    final mismatch = exitMismatchText(l, status);
    final ip = !settings.showPublicIp
        ? ''
        : status.exit?.ipv4.isNotEmpty == true
        ? status.exit!.ipv4
        : status.exit?.ipv6 ?? '';
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: pagePadding(context) + EdgeInsets.only(top: top),
      children: [
        Row(
          children: [
            Text(
              l.appTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Center(
          child: _PowerButton(
            on: on,
            accent: accent,
            busy: core.switchingProxy,
            tooltip: on ? l.tapToDisconnectPhone : l.tapToConnectPhone,
            // The one power behavior every home shares.
            onPressed: () => homePowerPressed(
              context,
              core,
              onNoAccounts: () => _openAccounts(context),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          confirming
              ? l.stateConnecting
              : connected
              ? l.stateConnected
              : look.label,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: on ? accent : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          look.hint.isNotEmpty
              ? look.hint
              : on
              ? l.tapToDisconnectPhone
              : l.tapToConnectPhone,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (connected && ip.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '${l.publicIp} ${ltr(ip)}',
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (mismatch != null) ...[
          const SizedBox(height: 10),
          Text(
            mismatch,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: StatusColors.busy,
            ),
          ),
        ],
        // The same connection mode selector as every home shows, where
        // this computer has more than proxy only.
        if (status.systemProxySupported || status.tunSupported) ...[
          const SizedBox(height: 24),
          Center(
            child: ConnectionModeSelector(
              core: core,
              status: status,
              card: scheme.surfaceContainerHigh,
              cardBorder: scheme.outlineVariant,
              text: scheme.onSurface,
              muted: scheme.onSurfaceVariant,
              accent: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            connectionModeHint(
              l,
              status,
              installing: core.installingTun,
              windows: defaultTargetPlatform == TargetPlatform.windows,
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          TunNote(
            core: core,
            box: (text, tooltip) => Tooltip(
              message: tooltip,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: StatusColors.busy.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: StatusColors.busy.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        _ActiveAccountCard(
          core: core,
          status: status,
          onOpenAccounts: () => _openAccounts(context),
        ),
        const SizedBox(height: 12),
        Panel(
          title: place.caption,
          icon: Icons.public_rounded,
          child: InkWell(
            onTap: onOpenServers,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                CountryFlag(code: place.flag, width: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    place.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
        if (status.traffic case final traffic?) ...[
          const SizedBox(height: 12),
          Panel(
            child: Row(
              children: [
                Icon(
                  Icons.arrow_upward_rounded,
                  size: 18,
                  color: StatusColors.good,
                ),
                const SizedBox(width: 6),
                Text(formatRate(traffic.upRate)),
                const SizedBox(width: 18),
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Text(formatRate(traffic.downRate)),
                const Spacer(),
                Text(
                  '${formatBytes(traffic.up)} ↑ · ${formatBytes(traffic.down)} ↓',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (status.totalAccounts == 0) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _openAccounts(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(l.addAccount),
          ),
        ],
      ],
    );
  }

  /// The accounts page where there is one; the sign-in form otherwise.
  void _openAccounts(BuildContext context) {
    if (onOpenAccounts != null) {
      onOpenAccounts!();
    } else {
      showSignInDialog(context, core);
    }
  }
}

/// The account carrying the traffic now, with its data bar; a tap opens
/// the accounts page.
class _ActiveAccountCard extends StatelessWidget {
  const _ActiveAccountCard({
    required this.core,
    required this.status,
    required this.onOpenAccounts,
  });

  final CoreController core;
  final CoreStatus status;
  final VoidCallback onOpenAccounts;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final a = status.activeAccount;
    final usage = a?.usage;
    return Panel(
      title: l.activeAccount,
      icon: Icons.person_rounded,
      child: InkWell(
        onTap: onOpenAccounts,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    a == null ? l.noActiveAccount : a.email,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textDirection: a == null ? null : TextDirection.ltr,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 12),
            if (a == null)
              Text(l.waitingForAccount, style: muted)
            else if (usage == null)
              Text(l.quotaNotRead, style: muted)
            else if (usage.unlimited)
              Text(l.unlimitedQuota, style: muted)
            else ...[
              QuotaBar(
                percent: a.usedPercent,
                threshold: status.thresholdPercent,
              ),
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
          ],
        ),
      ),
    );
  }
}

/// One big round connect button: a soft ring, a filled disc, the power
/// sign. A spinner's ring while the switch is being changed.
class _PowerButton extends StatelessWidget {
  const _PowerButton({
    required this.on,
    required this.accent,
    required this.busy,
    required this.tooltip,
    required this.onPressed,
  });

  final bool on;
  final Color accent;
  final bool busy;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const size = 184.0;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: on ? 0.26 : 0.10),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            Container(
              width: size - 16,
              height: size - 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: on ? 0.55 : 0.28),
                  width: 1.5,
                ),
              ),
            ),
            if (busy)
              SizedBox.square(
                dimension: size - 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accent,
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: size - 44,
              height: size - 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: on
                      ? [Color.lerp(accent, Colors.white, 0.28)!, accent]
                      : [
                          scheme.surfaceContainerHighest,
                          scheme.surfaceContainerHigh,
                        ],
                ),
                border: Border.all(
                  color: on
                      ? Colors.white.withValues(alpha: 0.4)
                      : scheme.outlineVariant,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: on ? 0.45 : 0.12),
                    blurRadius: on ? 34 : 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: busy ? null : onPressed,
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    size: 62,
                    color: on ? Colors.white : scheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
