import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'accounts_page.dart' show accountReason;
import 'format.dart';
import 'widgets.dart';
import 'zed_home_common.dart';

/// The Pixel design, ported from FoxyVPN's Android app: a hero card
/// whose color follows the connection, the morphing core and the state
/// inside it; fact chips under it; then the server, accounts and speed
/// rows. Tapping the place or account chip opens the connection
/// details; tapping the ping chip measures again.
class ZedPixelHome extends StatefulWidget {
  const ZedPixelHome({
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
  State<ZedPixelHome> createState() => _ZedPixelHomeState();
}

class _ZedPixelHomeState extends State<ZedPixelHome> {
  bool _detailsOpen = false;

  CoreController get core => widget.core;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = core.status!;
    final d = ZedHomeData(core, status, l,
        animationsEnabled: widget.settings.animationsEnabled);
    return ZedHomeScaffold(
      children: [
        const SizedBox(height: 8),
        _HeroCard(
          data: d,
          onToggle: () => d.toggle(context, widget.onOpenAccounts),
        ),
        const SizedBox(height: 10),
        _FactChips(
          data: d,
          onTap: () => setState(() => _detailsOpen = !_detailsOpen),
        ),
        if (_detailsOpen && d.live) ...[
          const SizedBox(height: 10),
          _DetailsPanel(data: d),
        ],
        if (d.hasError) ...[
          const SizedBox(height: 10),
          ZedErrorCard(text: d.errorText),
        ],
        const SizedBox(height: 10),
        ZedServerRow(
          data: d,
          onTap: () => widget.onOpenServers?.call(),
        ),
        const SizedBox(height: 10),
        ZedAccountsRow(
          data: d,
          onTap: () => d.openAccounts(context, widget.onOpenAccounts),
        ),
        const SizedBox(height: 10),
        ZedSpeedRow(data: d),
        const SizedBox(height: 10),
        ZedModeSection(data: d),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// The hero card: surface color at rest, the primary container's when
/// connected, both cross-faded; the state word slides and fades between
/// states; a progress line while connecting.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.data, required this.onToggle});

  final ZedHomeData data;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final live = data.live;
    final busy = data.busy;
    final ink = live ? scheme.onPrimaryContainer : scheme.onSurface;
    final sub = live
        ? scheme.onPrimaryContainer.withValues(alpha: 0.78)
        : scheme.onSurfaceVariant;
    final title = live
        ? l.stateConnected
        : busy
        ? l.stateConnecting
        : l.stateOff;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: live ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(44),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, box) => ZedConnectCore(
              live: live,
              busy: busy,
              since: data.since,
              size: (box.maxWidth * 0.52).clamp(116.0, 208.0),
              animationsEnabled: data.animationsEnabled,
              onToggle: onToggle,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            reverseDuration: const Duration(milliseconds: 160),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 1 / 3),
                      end: Offset.zero,
                    ).animate(animation),
                child: child,
              ),
            ),
            child: AnimatedDefaultTextStyle(
              key: ValueKey(title),
              duration: const Duration(milliseconds: 500),
              style:
                  (theme.textTheme.headlineSmall ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
              child: Text(title, textAlign: TextAlign.center),
            ),
          ),
          if (busy) ...[
            const SizedBox(height: 10),
            // The indeterminate line is an animation of its own: with
            // Home animations off it goes, like the door's motion —
            // the state word and the hint below still say connecting.
            if (data.animationsEnabled)
              SizedBox(
                width: 156,
                child: LinearProgressIndicator(
                  color: scheme.primary,
                  backgroundColor: scheme.primary.withValues(alpha: 0.18),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              l.zedTapCoreCancel,
              style: theme.textTheme.bodySmall?.copyWith(color: sub),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              live ? l.zedTrafficProtected : l.zedTapCoreConnect,
              style: theme.textTheme.bodySmall?.copyWith(color: sub),
            ),
          ],
        ],
      ),
    );
  }
}

/// The fact chips: the place; while connected, the ping and the
/// accounts in use. The place and account chips toggle the details
/// panel; the ping chip runs a new test instead, the same test the
/// details panel's refresh button runs.
class _FactChips extends StatelessWidget {
  const _FactChips({required this.data, required this.onTap});

  final ZedHomeData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final place = data.place;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _FactChip(
          onTap: onTap,
          children: [
            if (place.flag.length == 2) ...[
              CountryFlag(code: place.flag, width: 20),
              const SizedBox(width: 6),
            ] else ...[
              const Icon(Icons.public_rounded, size: 16),
              const SizedBox(width: 6),
            ],
            Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        if (data.live)
          _FactChip(
            onTap: () =>
                runShowingErrors(context, () => data.core.runTest()),
            children: [
              Text(
                data.pingMs == null
                    ? '${l.zedPing} …'
                    : '${data.pingMs} ms',
                maxLines: 1,
              ),
            ],
          ),
        if (data.live)
          _FactChip(
            onTap: onTap,
            children: [
              const Icon(Icons.account_circle_rounded, size: 16),
              const SizedBox(width: 6),
              Text('${data.ready}/${data.total}', maxLines: 1),
            ],
          ),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.onTap, required this.children});

  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: DefaultTextStyle.merge(
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: scheme.onSurfaceVariant),
              child: Row(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    );
  }
}

/// The connection details the chips open: location, ping, and every
/// account with what it is doing; the refresh button runs a new test.
class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.data});

  final ZedHomeData data;

  String _accountValue(AppLocalizations l, Account a) {
    if (!a.enabled) return l.zedAccountOff;
    final usage = a.usage;
    if (usage != null &&
        !usage.unlimited &&
        usage.limitBytes > 0 &&
        usage.usedBytes >= usage.limitBytes) {
      return l.zedQuotaExhausted;
    }
    if (a.active && data.live) {
      final traffic = data.status.traffic;
      if (traffic != null) {
        return '↓ ${formatRate(traffic.downRate)} · ↑ ${formatRate(traffic.upRate)}';
      }
    }
    if (a.status == AccountStatus.ready) return l.statusActive;
    return accountReason(l, a, data.status.thresholdPercent) ?? l.zedIdle;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accounts = data.accounts;
    Widget row(String label, String value) => Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.labelLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.zedConnectionDetails,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    runShowingErrors(context, () => data.core.runTest()),
                iconSize: 18,
                icon: const Icon(Icons.refresh_rounded),
                color: scheme.onSurfaceVariant,
                tooltip: l.testConnection,
              ),
            ],
          ),
          const SizedBox(height: 8),
          row(l.homeLocation, data.place.name),
          const SizedBox(height: 8),
          row(
            l.zedPing,
            data.pingMs == null
                ? l.zedPingUnavailable
                : '${data.pingMs} ms',
          ),
          const SizedBox(height: 8),
          if (accounts.isEmpty)
            Text(
              l.waitingForAccount,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            for (final a in accounts) ...[
              row(a.email.isEmpty ? l.activeAccount : a.email, _accountValue(l, a)),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}
