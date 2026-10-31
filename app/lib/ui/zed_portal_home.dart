import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_controller.dart';
import '../l10n/app_localizations.dart';
import 'widgets.dart';
import 'zed_home_common.dart';

/// The Portal design, ported from FoxyVPN's Android app: an immersive
/// single column — the state word, the connect core glowing inside two
/// rings at the center, and every fact in one unified card below; then
/// the server, accounts and speed rows.
class ZedPortalHome extends StatelessWidget {
  const ZedPortalHome({
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
        ? l.stateConnected
        : d.busy
        ? l.stateConnecting
        : l.stateOff;
    final ring = d.live
        ? scheme.primary
        : d.busy
        ? scheme.tertiary
        : scheme.surfaceContainerHighest;
    return ZedHomeScaffold(
      children: [
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          reverseDuration: const Duration(milliseconds: 150),
          child: Text(
            title,
            key: ValueKey(title),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: d.live ? scheme.primary : scheme.onSurface,
            ),
          ),
        ),
        if (d.live) ...[
          const SizedBox(height: 4),
          Center(
            child: ZedElapsedText(
              since: d.since,
              style: theme.textTheme.titleMedium,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Center(
          child: SizedBox.square(
            dimension: 236,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 236,
                  height: 236,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ring.withValues(alpha: 0.14),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 208,
                  height: 208,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ring.withValues(alpha: 0.20),
                  ),
                ),
                ZedConnectCore(
                  live: d.live,
                  busy: d.busy,
                  since: d.since,
                  size: 200,
                  animationsEnabled: d.animationsEnabled,
                  onToggle: () => d.toggle(context, onOpenAccounts),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              _InfoRow(
                label: l.homeLocation,
                value: d.place.name,
                flagCode: d.place.flag,
              ),
              Divider(
                indent: 20,
                endIndent: 20,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              _InfoRow(
                label: l.zedPing,
                value: d.pingMs == null ? '—' : '${d.pingMs} ms',
                onTap: d.live
                    ? () => runShowingErrors(context, () => d.core.runTest())
                    : null,
              ),
              Divider(
                indent: 20,
                endIndent: 20,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              _InfoRow(
                label: l.navAccounts,
                value: l.zedAccountsActive(d.live ? d.ready : 0, d.total),
              ),
            ],
          ),
        ),
        if (d.hasError) ...[
          const SizedBox(height: 12),
          ZedErrorCard(text: d.errorText),
        ],
        const SizedBox(height: 12),
        ZedServerRow(data: d, onTap: () => onOpenServers?.call()),
        const SizedBox(height: 12),
        ZedAccountsRow(
          data: d,
          onTap: () => d.openAccounts(context, onOpenAccounts),
        ),
        const SizedBox(height: 12),
        ZedSpeedRow(data: d),
        const SizedBox(height: 12),
        ZedModeSection(data: d),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// One fact of the Portal card: the label at the start, the flag and
/// the value at the end. With an [onTap] the row answers taps (the
/// ping row measures again); without one it is inert.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.flagCode,
    this.onTap,
  });

  final String label;
  final String value;
  final String? flagCode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (flagCode != null && flagCode!.length == 2) ...[
            CountryFlag(code: flagCode!, width: 22),
            const SizedBox(width: 6),
          ],
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
