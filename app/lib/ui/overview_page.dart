import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../app_settings.dart';
import '../core/android_core.dart';
import '../core/core_controller.dart';
import '../core/updates.dart';
import '../core/models.dart';
import '../core/ports.dart';
import '../l10n/app_localizations.dart';
import '../platform.dart';
import 'browser_signin.dart';
import 'bypass_apps_page.dart';
import 'connection_mode.dart';
import 'format.dart';
import 'port_dialog.dart';
import 'widgets.dart';
import 'zed/zed_connect.dart';
import 'zed/zed_home.dart';
import 'zed/zed_prefs.dart';
import 'zed/zed_theme.dart';

/// The home page: the switch, the state, where the traffic goes, and the
/// data used; the phone's (_PhoneHome) and the computer's (_DesktopHome)
/// share the look, not the logic. Developer mode adds the details.
class OverviewPage extends StatelessWidget {
  const OverviewPage({
    super.key,
    required this.core,
    required this.settings,
    this.onOpenServers,
    this.onOpenAccounts,
    this.onOpenConnection,
    this.onOpenUpstreamProxy,
    this.phone = false,
  });

  final CoreController core;
  final AppSettings settings;

  /// The phone layout: a colored hero and the data left (_PhoneHome).
  final bool phone;

  /// Opens the server list and the accounts from the home page's cards (a
  /// page on the phone, a tab on the computer).
  final VoidCallback? onOpenServers;
  final VoidCallback? onOpenAccounts;

  /// Opens the connection settings, when Mozilla's servers are blocked.
  final VoidCallback? onOpenConnection;
  final VoidCallback? onOpenUpstreamProxy;

  @override
  Widget build(BuildContext context) {
    final status = core.status!;
    final showIp = settings.showPublicIp;
    if (phone) {
      return _PhoneHome(
        core: core,
        status: status,
        showIp: showIp,
        settings: settings,
        onOpenServers: onOpenServers,
        onOpenAccounts: onOpenAccounts,
        onOpenConnection: onOpenConnection,
        onOpenUpstreamProxy: onOpenUpstreamProxy,
      );
    }
    return _DesktopHome(
      core: core,
      status: status,
      showIp: showIp,
      settings: settings,
      onOpenServers: onOpenServers,
      onOpenAccounts: onOpenAccounts,
      onOpenConnection: onOpenConnection,
      onOpenUpstreamProxy: onOpenUpstreamProxy,
    );
  }
}

/// Opens the connection settings under "Mozilla's servers are blocked":
/// HTTP/2, HTTP/3, or HTTP/1.1, one of which a network may let through.
class _ConnectionSettingsButton extends StatelessWidget {
  const _ConnectionSettingsButton({required this.onPressed, this.label});

  final VoidCallback onPressed;

  /// The button's text; "Connection settings" without it.
  final String? label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: Text(label ?? AppLocalizations.of(context).connectionSettings),
      ),
    ),
  );
}

/// Under "This location isn't available for your account": switches to
/// Mozilla's recommended location (an empty `proxy.country`).
class _RecommendedLocationButton extends StatelessWidget {
  const _RecommendedLocationButton({required this.core});

  final CoreController core;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Center(
      child: TextButton.icon(
        onPressed: () => runShowingErrors(context, () => core.setLocation('')),
        icon: const Icon(Icons.public_rounded, size: 18),
        label: Text(AppLocalizations.of(context).useRecommendedLocation),
      ),
    ),
  );
}

/// An amber box when another program (another VPN or proxy) replaced the
/// system proxy the core set, so applications no longer use the VPN; the
/// button takes it back. The core never does that by itself.
class _SystemProxyTakenNote extends StatelessWidget {
  const _SystemProxyTakenNote({required this.core, required this.by});

  final CoreController core;

  /// What the system proxy points at now; empty when it was turned off.
  final String by;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProblemBox(
            text: by.isEmpty
                ? l.systemProxyTakenOff
                : l.systemProxyTakenBy(ltr(by)),
            color: StatusColors.busy,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () =>
                runShowingErrors(context, () => core.setSystemProxy('set')),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l.setSystemProxyAgain),
          ),
        ],
      ),
    );
  }
}

/// An amber box when the public IP is in another country than the chosen
/// one: a hint, not an error; the connection works.
class _ExitMismatchNote extends StatelessWidget {
  const _ExitMismatchNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: _ProblemBox(
      text: text,
      color: StatusColors.busy,
      icon: Icons.warning_amber_rounded,
    ),
  );
}

/// The widest a [_ProblemBox] grows.
const _problemBoxWidth = 460.0;

/// A home-page problem in a tinted box, so it stands out from the ordinary
/// hints: red for an error, amber for a warning. The text is darkened (or,
/// at night, lightened) toward the page's text for contrast on the tint.
class _ProblemBox extends StatelessWidget {
  const _ProblemBox({
    required this.text,
    required this.color,
    required this.icon,
    this.tooltip = '',
  });

  final String text;
  final Color color;
  final IconData icon;

  /// The core's own words, on hover or a long press.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = Color.lerp(color, dark ? Colors.white : Colors.black, 0.25)!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _problemBoxWidth),
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 14, 9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: dark ? 0.18 : 0.11),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: ink, fontWeight: FontWeight.w600),
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

/// The accounts page, from the power button without an account; the
/// sign-in form when no page is given.
void _openAccounts(
  BuildContext context,
  CoreController core,
  AppSettings settings,
  VoidCallback? onOpenAccounts,
) {
  if (onOpenAccounts != null) {
    onOpenAccounts();
  } else {
    startAddAccount(context, core, settings);
  }
}

/// The core handles the initial connection while an explicit attempt is pending.
void _testAfterPowerOn(CoreController core) {
  final status = core.status;
  if (status != null && status.proxyOn && !status.connectPending) {
    unawaited(core.runTest().catchError((_) {}));
  }
}

/// The computer's home: the phone's look with the computer's logic. The
/// button turns the proxy on or off (off closes its port and gives Windows
/// its own proxy setting back); the mode chooses who uses it: Proxy, apps
/// set up by hand, or System proxy, Windows too. Switching modes never
/// disconnects. "Connecting" in orange until a test confirms the
/// connection. Where the traffic goes and the data used are in cards; the
/// email is on the accounts page.
class _DesktopHome extends StatelessWidget {
  const _DesktopHome({
    required this.core,
    required this.status,
    required this.showIp,
    required this.settings,
    this.onOpenServers,
    this.onOpenAccounts,
    this.onOpenConnection,
    this.onOpenUpstreamProxy,
  });

  final CoreController core;
  final CoreStatus status;

  /// Settings, Show the public IP.
  final bool showIp;
  final AppSettings settings;
  final VoidCallback? onOpenServers;
  final VoidCallback? onOpenAccounts;
  final VoidCallback? onOpenConnection;
  final VoidCallback? onOpenUpstreamProxy;

  /// The connection mode shown as chosen; changing it (chooseConnectionMode)
  /// keeps the proxy running and connected.
  String get _mode => connectionModeShown(status);

  /// The button: off, or on with a test that confirms the connection.
  Future<void> _power(bool on) async {
    await core.setOn(on);
    if (on) _testAfterPowerOn(core);
  }

  @override
  Widget build(BuildContext context) {
    final p = _zedHomePalette(context, settings);
    // Bento motifs: the soft background lights, off when the design's
    // motifs are off (other designs always show theirs).
    final motifs =
        settings.zedPrefs.design != ZedDesign.bento ||
        settings.zedPrefs.bento.motifs;
    final page = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.top, p.bottom],
        ),
      ),
      child: Stack(
        children: [
          if (motifs)
            Positioned(
              top: -140,
              left: -120,
              child: _Glow(
                color: _accent(p),
                size: 420,
                alpha: p.dark ? 0.20 : 0.18,
              ),
            ),
          if (motifs)
            Positioned(
              top: 120,
              right: -160,
              child: _Glow(
                color: p.second,
                size: 360,
                alpha: p.dark ? 0.12 : 0.15,
              ),
            ),
          if (motifs)
            Positioned(
              bottom: -120,
              left: 40,
              child: _Glow(
                color: p.third,
                size: 320,
                alpha: p.dark ? 0.10 : 0.10,
              ),
            ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _content(context, p),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return page;
  }

  bool get _running => status.state.phase == Phase.running;

  /// The core is connecting, or the proxy still needs a passing test.
  bool get _confirming =>
      status.connectPending ||
      (status.proxyOn && _running && !status.confirmedBy(core.lastTest));

  Color _accent(_HomePalette p) => switch (status.state.phase) {
    _ when status.connectPending => p.busy,
    _ when !status.proxyOn => p.idle,
    Phase.error => p.error,
    Phase.running when _confirming => p.busy,
    Phase.running => p.connected,
    Phase.starting => p.busy,
    _ => p.idle,
  };

  Widget _content(BuildContext context, _HomePalette p) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final look = PhaseLook.of(l, status);
    // Pixel/Old: the user's custom tap-hint colour, when set.
    final tapHintColor =
        (settings.zedPrefs.design == ZedDesign.pixel ||
                settings.zedPrefs.design == ZedDesign.old) &&
            settings.zedPrefs.activePixel.customTapHint != null
        ? Color(settings.zedPrefs.activePixel.customTapHint!)
        : p.muted;

    final proxy = status.proxy;
    final on = status.proxyOn;
    final confirming = _confirming;
    final test = status.isCurrentTest(core.lastTest) ? core.lastTest : null;
    final noNetwork = !status.connectPending && status.noNetwork && on;
    final failing =
        !status.connectPending &&
        confirming &&
        ((proxy?.wakeError.isNotEmpty ?? false) || test?.ok == false);
    // The real reason; a long press or hover shows the core's own text.
    final failure = failing ? failureText(l, proxy, test) : null;
    // The last connect was given up: why, until the next one.
    final gaveUp = !on && status.connectFailure.isNotEmpty;
    final connected = on && _running && !confirming;
    final accent = _accent(p);
    final ip = !showIp
        ? ''
        : status.exit?.ipv4.isNotEmpty == true
        ? status.exit!.ipv4
        : status.exit?.ipv6 ?? '';
    final place = homeLocation(l, status, connected: connected);
    final mismatch = exitMismatchText(l, status);
    // Glass homeCard off hides the server module card.
    final showPlaceCard =
        settings.zedPrefs.design != ZedDesign.glass ||
        settings.zedPrefs.glass.homeCard;
    final cards = [
      if (showPlaceCard)
        _PlaceCard(
          palette: p,
          compact: true,
          place: place,
          accent: accent,
          onTap: onOpenServers,
        ),
      _HomeData(
        status: status,
        palette: p,
        onTap: onOpenAccounts,
        compact: true,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZedHero(
          prefs: settings.zedPrefs,
          spec: _zedSpec(
            l: l,
            status: status,
            on: on,
            busy: core.switchingProxy,
            connecting: confirming || status.state.phase == Phase.starting,
            connected: connected,
            stateLabel: confirming
                ? l.stateConnecting
                : connected
                ? l.stateConnected
                : look.label,
            hint: on ? l.tapToDisconnect : l.tapToConnect,
            onToggle: () => status.totalAccounts == 0
                ? _openAccounts(context, core, settings, onOpenAccounts)
                : runShowingErrors(context, () => _power(!on)),
          ),
          upText: formatRate(status.traffic?.upRate ?? 0),
          downText: formatRate(status.traffic?.downRate ?? 0),
          upRate: (status.traffic?.upRate ?? 0).toDouble(),
          downRate: (status.traffic?.downRate ?? 0).toDouble(),
          onOpenServers: onOpenServers,
          onOpenAccounts: onOpenAccounts,
          serversLabel: l.navServers,
          accountsLabel: l.navAccounts,
        ),
        const SizedBox(height: 8),
        if (connected)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _HomeDelay(core: core, palette: p),
              if (ip.isNotEmpty)
                _HomePill(
                  palette: p,
                  child: Text(
                    '${l.publicIp} ${ltr(ip)}',
                    style: theme.textTheme.labelLarge?.copyWith(color: p.muted),
                  ),
                ),
              if (status.upstreamProxy.isNotEmpty)
                _UpstreamProxyPill(
                  address: status.upstreamProxy,
                  palette: p,
                  onPressed: onOpenUpstreamProxy,
                ),
            ],
          )
        else if (failing || noNetwork || gaveUp)
          // Not connecting stands out from the ordinary hints.
          _ProblemBox(
            text: noNetwork
                ? l.noNetwork
                : failure != null
                ? failure.text
                : failureCodeText(l, status.connectFailure),
            color: p.error,
            icon: Icons.error_outline_rounded,
            tooltip: noNetwork ? '' : failure?.detail ?? '',
          )
        else
          // A start failure's hint is general; the core's reason is on
          // hover or a long press.
          Tooltip(
            message: !status.connectPending && status.state.phase == Phase.error
                ? status.state.message
                : '',
            child: Text(
              !on ? l.tapToConnect : look.hint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: tapHintColor),
            ),
          ),
        if (failure?.code == Failure.unreachable && onOpenConnection != null)
          _ConnectionSettingsButton(onPressed: onOpenConnection!),
        if (failure?.code == Failure.upstreamProxy &&
            onOpenUpstreamProxy != null)
          _ConnectionSettingsButton(
            onPressed: onOpenUpstreamProxy!,
            label: AppLocalizations.of(context).upstreamProxy,
          ),
        if (!connected &&
            status.upstreamProxy.isNotEmpty &&
            failure?.code != Failure.upstreamProxy)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: _UpstreamProxyPill(
                address: status.upstreamProxy,
                palette: p,
                onPressed: onOpenUpstreamProxy,
              ),
            ),
          ),
        if (isLocationRefused(failure?.code ?? '') ||
            (gaveUp && isLocationRefused(status.connectFailure)))
          _RecommendedLocationButton(core: core),
        if (connected && mismatch != null) _ExitMismatchNote(text: mismatch),
        if (status.systemProxySet && status.systemProxyTakenBy != null)
          _SystemProxyTakenNote(core: core, by: status.systemProxyTakenBy!),
        if (status.state.proxyPortBlocked) ...[
          const SizedBox(height: 12),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: () async {
                final port = await showPortDialog(
                  context,
                  taken: status.state.address,
                );
                if (port != null && context.mounted) {
                  await runShowingErrors(
                    context,
                    () => core.setProxyPort(port),
                  );
                }
              },
              icon: const Icon(Icons.settings_ethernet_rounded),
              label: Text(l.changePort),
            ),
          ),
        ],
        const SizedBox(height: 16),
        // The same choice as the button and the tray, by name, where this
        // computer has more than proxy only.
        if (status.systemProxySupported || status.tunSupported)
          Center(
            child: _ModeSwitch(
              palette: p,
              accent: accent,
              selected: _mode,
              onSelected: core.switchingProxy || core.installingTun
                  ? null
                  : (mode) => chooseConnectionMode(context, core, mode),
              modes: [
                (
                  value: 'clear',
                  icon: Icons.settings_ethernet_rounded,
                  label: l.modeProxy,
                  // Where apps set up by hand find the proxy, which always
                  // runs.
                  tooltip: _running && proxy != null
                      ? '${l.proxyServiceActive} · ${proxy.listen}'
                      : '',
                ),
                if (status.systemProxySupported)
                  (
                    value: 'set',
                    icon: Icons.computer_rounded,
                    label: l.systemProxy,
                    tooltip: '',
                  ),
                if (status.tunSupported)
                  (
                    value: 'tun',
                    icon: Icons.vpn_lock_rounded,
                    label: l.modeTun,
                    tooltip: '',
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          // Windows names itself; Linux and macOS say "the system".
          connectionModeHint(
            l,
            status,
            installing: core.installingTun,
            windows: defaultTargetPlatform == TargetPlatform.windows,
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
        ),
        TunNote(
          core: core,
          box: (text, tooltip) => _ProblemBox(
            text: text,
            color: StatusColors.busy,
            icon: Icons.warning_amber_rounded,
            tooltip: tooltip,
          ),
        ),
        const SizedBox(height: 24),
        _UpdateNotice(core: core, settings: settings, palette: p),
        _UdpNotice(status: status, settings: settings, palette: p),
        _Notices(notices: homeNotices(status.notices)),
        _LowQuotaNotice(
          core: core,
          status: status,
          settings: settings,
          connected: connected,
          palette: p,
        ),
        // Side by side when there is room.
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 560
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[1]),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [cards[0], const SizedBox(height: 12), cards[1]],
                ),
        ),
      ],
    );
  }
}

/// A small frosted pill on the home background.
class _HomePill extends StatelessWidget {
  const _HomePill({required this.palette, required this.child});

  final _HomePalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: ShapeDecoration(
      color: palette.card,
      shape: StadiumBorder(side: BorderSide(color: palette.cardBorder)),
    ),
    child: child,
  );
}

/// While the upstream proxy is on: says so whatever the connection's state, with
/// its address on hover or a long press, and opens its settings.
class _UpstreamProxyPill extends StatelessWidget {
  const _UpstreamProxyPill({
    required this.address,
    required this.palette,
    this.onPressed,
  });

  final String address;
  final _HomePalette palette;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: ltr(address),
    child: Material(
      color: palette.card,
      shape: StadiumBorder(side: BorderSide(color: palette.cardBorder)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lan_outlined, size: 16, color: palette.connected),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).upstreamProxyOn,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A connection mode in [_ModeSwitch]; an empty tooltip shows none.
typedef _Mode = ({String value, IconData icon, String label, String tooltip});

/// The connection modes as one rounded track with no lines between them:
/// the chosen mode sits on a pill that slides to the one tapped. The modes
/// are equally wide (the widest one's width), and the whole track shrinks
/// to fit a narrow window. A tap on the chosen mode changes nothing.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.palette,
    required this.accent,
    required this.modes,
    required this.selected,
    required this.onSelected,
    this.onTapSelected,
  });

  final _HomePalette palette;
  final Color accent;
  final List<_Mode> modes;
  final String selected;

  /// Null while a change is under way.
  final ValueChanged<String>? onSelected;

  /// Called when the already-chosen mode is tapped (e.g. to open its settings).
  final ValueChanged<String>? onTapSelected;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final theme = Theme.of(context);
    final n = modes.length;
    final index = modes.indexWhere((m) => m.value == selected);
    final still = MediaQuery.of(context).disableAnimations;
    final onSelected = this.onSelected;
    Widget option(_Mode m) {
      final chosen = m.value == selected;
      final color = chosen ? p.text : p.muted;
      Widget child = InkWell(
        customBorder: const StadiumBorder(),
        onTap: onSelected == null
            ? null
            : chosen
            ? (onTapSelected != null ? () => onTapSelected!(m.value) : null)
            : () => onSelected(m.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(m.icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                m.label,
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: chosen ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
      if (m.tooltip.isNotEmpty) {
        child = Tooltip(message: m.tooltip, child: child);
      }
      return Semantics(
        button: true,
        selected: chosen,
        enabled: onSelected != null,
        child: child,
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: AnimatedOpacity(
        opacity: onSelected == null ? 0.6 : 1,
        duration: const Duration(milliseconds: 150),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: p.card,
            shape: StadiumBorder(side: BorderSide(color: p.cardBorder)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            // The row is as wide as its widest mode times their number
            // (each mode Expanded under IntrinsicWidth), so the pill is one
            // mode wide wherever it is.
            child: IntrinsicWidth(
              child: Stack(
                children: [
                  if (index >= 0)
                    Positioned.fill(
                      child: AnimatedAlign(
                        alignment: AlignmentDirectional(
                          n == 1 ? 0 : -1 + 2 * index / (n - 1),
                          0,
                        ),
                        duration: still
                            ? Duration.zero
                            : const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: FractionallySizedBox(
                          widthFactor: 1 / n,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: accent.withValues(alpha: 0.2),
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: accent.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // A line between two modes, so each reads as a button of
                  // its own; none beside the pill, which marks its mode.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          for (var i = 0; i < n; i++)
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: i == n - 1
                                    ? null
                                    : AnimatedOpacity(
                                        opacity: i == index || i + 1 == index
                                            ? 0
                                            : 1,
                                        duration: still
                                            ? Duration.zero
                                            : const Duration(milliseconds: 180),
                                        child: Container(
                                          width: 1.2,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: p.muted.withValues(
                                              alpha: 0.45,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              1,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: Row(
                      children: [
                        for (final m in modes) Expanded(child: option(m)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the traffic goes: the flag and the country, under how the
/// location is chosen (a sparkle for the app's choice); a tap opens the
/// server list.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.palette,
    required this.place,
    required this.accent,
    this.onTap,
    this.compact = false,
  });

  final _HomePalette palette;
  final HomePlace place;
  final Color accent;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = palette;
    return _HomeCard(
      palette: p,
      onTap: onTap,
      compact: compact,
      // As tall as the data card's ring, so the two cards match.
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _homeCardContent(compact)),
        child: Row(
          children: [
            CountryFlag(code: place.flag, width: compact ? 34 : 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (place.auto) ...[
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          place.caption,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: place.auto ? accent : p.muted,
                            fontWeight: place.auto ? FontWeight.w600 : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.name,
                    style:
                        (compact
                                ? theme.textTheme.titleSmall
                                : theme.textTheme.titleMedium)
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: p.text,
                            ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: p.muted),
          ],
        ),
      ),
    );
  }
}

class _HomePalette {
  const _HomePalette({
    required this.dark,
    required this.top,
    required this.bottom,
    required this.text,
    required this.muted,
    required this.card,
    required this.cardBorder,
    required this.idle,
    required this.connected,
    required this.busy,
    required this.error,
    required this.second,
    required this.third,
    required this.discOff,
    required this.discOffEdge,
  });

  final bool dark;
  final Color top;
  final Color bottom;
  final Color text;
  final Color muted;
  final Color card;
  final Color cardBorder;
  final Color idle;
  final Color connected;
  final Color busy;
  final Color error;

  /// Colors of the background's soft lights, with the state's.
  final Color second;
  final Color third;
  final List<Color> discOff;
  final Color discOffEdge;
}

/// Session elapsed text from the engine state's start time.
String _fmtElapsed(DateTime? since) {
  if (since == null) return '';
  final d = DateTime.now().difference(since);
  if (d.isNegative) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return d.inHours > 0
      ? '${d.inHours}:${two(m)}:${two(s)}'
      : '${two(d.inMinutes)}:${two(s)}';
}

/// The home palette of the active ZedSecure design: the stock day /
/// night palettes are gone — every design paints its home from its
/// own tokens (Bento ground + tones, Pixel scheme, Glass tokens over
/// the shell's wallpaper).
_HomePalette _zedHomePalette(BuildContext context, AppSettings settings) {
  final prefs = settings.zedPrefs;
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  switch (prefs.design) {
    case ZedDesign.bento:
      final t = bentoTokensFor(
        prefs.bento.palette,
        dark,
        amoled: prefs.bento.amoled,
        seedArgb: pixelAccents[prefs.pixel.accentIndex.clamp(0, 9)].toARGB32(),
      );
      return _HomePalette(
        dark: t.dark,
        top: t.ground,
        bottom: t.ground,
        text: t.ink,
        muted: t.muted,
        card: t.surface,
        cardBorder: t.line,
        idle: t.violet.container,
        connected: t.lime,
        busy: t.mid,
        error: t.danger,
        second: t.blue.container,
        third: t.pink.container,
        discOff: [t.surface2, t.surface],
        discOffEdge: t.line,
      );
    case ZedDesign.glass:
      final g = glassTokensFor(prefs.glass, dark);
      return _HomePalette(
        dark: g.dark,
        top: Colors.transparent,
        bottom: Colors.transparent,
        text: g.label,
        muted: g.label2,
        card: g.module,
        cardBorder: g.separator,
        idle: g.tint,
        connected: g.green,
        busy: g.orange,
        error: g.red,
        second: g.tint,
        third: const Color(0xFFE05BE6),
        discOff: [g.cell, g.cell],
        discOffEdge: g.separator,
      );
    case ZedDesign.pixel || ZedDesign.old:
      final scheme = theme.colorScheme;
      final p = prefs.activePixel;
      final connectedColor = p.customConnected != null
          ? Color(p.customConnected!)
          : scheme.tertiary;
      return _HomePalette(
        dark: dark,
        top: dark ? const Color(0xFF111218) : const Color(0xFFF5F5FA),
        bottom: dark ? const Color(0xFF0D0E13) : const Color(0xFFECECF4),
        text: scheme.onSurface,
        muted: scheme.onSurfaceVariant,
        card: scheme.surfaceContainerLow,
        cardBorder: scheme.outlineVariant.withValues(alpha: 0.4),
        idle: p.customConnect != null
            ? Color(p.customConnect!)
            : scheme.primary,
        connected: connectedColor,
        busy: const Color(0xFFF08C00),
        error: scheme.error,
        second: scheme.secondary,
        third: scheme.tertiary,
        discOff: [scheme.surfaceContainerHigh, scheme.surfaceContainer],
        discOffEdge: scheme.outlineVariant,
      );
  }
}

/// The connect-control spec for the hero, from the same state the
/// stock orb was fed with.
ZedConnectSpec _zedSpec({
  required AppLocalizations l,
  required CoreStatus status,
  required bool on,
  required bool busy,
  required bool connecting,
  required bool connected,
  required String stateLabel,
  required String hint,
  required VoidCallback onToggle,
}) {
  final phase = status.state.phase == Phase.error && on
      ? ZedPhase.error
      : connected
      ? ZedPhase.on
      : (busy || connecting)
      ? ZedPhase.busy
      : ZedPhase.off;
  return ZedConnectSpec(
    phase: phase,
    stateLabel: stateLabel,
    actionLabel: hint,
    hint: hint,
    serverName: status.proxy?.countryName ?? '',
    elapsed: connected ? _fmtElapsed(status.state.since) : '',
    onToggle: onToggle,
  );
}

/// The phone's home: the switch in the middle over soft lights and wavy
/// contour lines in the state's color, the state under it, then where the
/// traffic goes and the data used. Light or dark with the app's theme; the
/// email is on the accounts page.
class _PhoneHome extends StatelessWidget {
  const _PhoneHome({
    required this.core,
    required this.status,
    required this.showIp,
    required this.settings,
    this.onOpenServers,
    this.onOpenAccounts,
    this.onOpenConnection,
    this.onOpenUpstreamProxy,
  });

  final CoreController core;
  final CoreStatus status;

  /// Settings, Show the public IP.
  final bool showIp;
  final AppSettings settings;
  final VoidCallback? onOpenServers;
  final VoidCallback? onOpenAccounts;
  final VoidCallback? onOpenConnection;
  final VoidCallback? onOpenUpstreamProxy;

  Future<void> _toggle(bool on) async {
    await core.setOn(!on);
    if (!on) _testAfterPowerOn(core);
  }

  void _openBypassApps(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const BypassAppsPage()))
        .then((_) async {
          try {
            final r = await AndroidCore.appRouting();
            AndroidCore.appRoutingMode.value =
                (r.onlyChosen || r.bypass.isNotEmpty) ? 'selected' : 'all';
            AndroidCore.selectedAppsCount.value = r.chosenCount;
          } catch (_) {}
        });
  }

  Future<void> _openPortSettings(
    BuildContext context,
    CoreStatus status,
  ) async {
    final port = await showPortDialog(context, taken: status.state.address);
    if (port != null && context.mounted) {
      await runShowingErrors(context, () => core.setProxyPort(port));
    }
  }

  void _openAllAppsSettings() {
    if (onOpenConnection != null) {
      onOpenConnection!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _zedHomePalette(context, settings);
    final page = AnnotatedRegion<SystemUiOverlayStyle>(
      value: (p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.top, p.bottom],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(child: _content(context, p, box)),
            ),
          ),
        ),
      ),
    );
    return page;
  }

  Widget _content(BuildContext context, _HomePalette p, BoxConstraints box) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final look = PhaseLook.of(l, status);
    // Pixel/Old: the user's custom tap-hint colour, when set.
    final tapHintColor =
        (settings.zedPrefs.design == ZedDesign.pixel ||
                settings.zedPrefs.design == ZedDesign.old) &&
            settings.zedPrefs.activePixel.customTapHint != null
        ? Color(settings.zedPrefs.activePixel.customTapHint!)
        : p.muted;

    final running = status.state.phase == Phase.running;
    // Connecting, or connected but still waiting on a passing test: the
    // same orange state the label shows, so the ring moves with it.
    final connecting =
        status.connectPending ||
        status.state.phase == Phase.starting ||
        (status.proxyOn && running && !status.confirmedBy(core.lastTest));
    final canSwitch = status.systemProxySupported;
    final width = box.maxWidth;
    // Not enough height for the switch at its full size: it shrinks and
    // the spacing tightens, so the location and the quota still show
    // without scrolling. A window pinned to the side of a screen is as
    // short as a TV is (960 x 540), and narrower.
    final short = box.maxHeight < 700;
    // The two cards fit beside each other only when the width is there;
    // narrower, each would be too narrow for its own name and would break
    // the words. They stay one above the other then, which the smaller
    // switch has made room for.
    final sideBySide = short && width >= 600;
    // On a tablet the content keeps about a phone's width in the middle (the
    // colors still reach the edges), and the problem boxes their own limit.
    // Both as padding, since IntrinsicHeight measures through padding but
    // not through a width limit.
    final side = math.max(20.0, (width - (sideBySide ? 720 : 560)) / 2);
    final boxSide = math.max(0.0, (width - 2 * side - _problemBoxWidth) / 2);
    Widget problem(Widget box) => Padding(
      padding: EdgeInsets.symmetric(horizontal: boxSide),
      child: box,
    );
    final on = status.proxyOn;
    final proxy = status.proxy;
    // The phone's VPN is "Connecting", in orange, until a test confirms it
    // works (the controller tests again meanwhile): with no internet it
    // does not claim to be connected.
    final confirming =
        status.connectPending ||
        (on && running && !canSwitch && !status.confirmedBy(core.lastTest));
    final test = status.isCurrentTest(core.lastTest) ? core.lastTest : null;
    final noNetwork = !status.connectPending && status.noNetwork && on;
    final failing =
        !status.connectPending &&
        confirming &&
        ((proxy?.wakeError.isNotEmpty ?? false) || test?.ok == false);
    // The real reason; a long press or hover shows the core's own text.
    final failure = failing ? failureText(l, proxy, test) : null;
    // The last connect was given up: why, until the next one.
    final gaveUp = !on && status.connectFailure.isNotEmpty;
    final connected =
        on && running && (status.computerUsesVpn || !canSwitch) && !confirming;
    final ip = !showIp
        ? ''
        : status.exit?.ipv4.isNotEmpty == true
        ? status.exit!.ipv4
        : status.exit?.ipv6 ?? '';
    final proxyOnly = Platform.isAndroid && AndroidCore.mode.value == 'proxy';
    final accent = !on
        ? p.idle
        : confirming
        ? p.busy
        : switch (status.state.phase) {
            Phase.running => p.connected,
            Phase.error => p.error,
            _ => p.busy,
          };
    final label = confirming ? l.stateConnecting : look.label;
    final press = on ? l.tapToDisconnectPhone : l.tapToConnectPhone;
    final place = homeLocation(l, status, connected: connected);
    // Glass homeCard off hides the server module card.
    final showPlaceCard =
        settings.zedPrefs.design != ZedDesign.glass ||
        settings.zedPrefs.glass.homeCard;
    final mismatch = exitMismatchText(l, status);
    final top = MediaQuery.paddingOf(context).top;
    // Bento motifs gate the soft background lights (see desktop).
    final motifs =
        settings.zedPrefs.design != ZedDesign.bento ||
        settings.zedPrefs.bento.motifs;
    return Stack(
      children: [
        // Soft lights in the state's color and two others.
        if (motifs)
          Positioned(
            top: -120,
            left: -100,
            child: _Glow(color: accent, size: 360, alpha: p.dark ? 0.22 : 0.20),
          ),
        if (motifs)
          Positioned(
            top: 160,
            right: -140,
            child: _Glow(
              color: p.second,
              size: 320,
              alpha: p.dark ? 0.12 : 0.16,
            ),
          ),
        if (motifs)
          Positioned(
            bottom: -80,
            left: -60,
            child: _Glow(
              color: p.third,
              size: 300,
              alpha: p.dark ? 0.10 : 0.12,
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(side, top + 14, side, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppLogo(size: 28),
                  const SizedBox(width: 8),
                  Text(
                    l.appTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(height: short ? 4 : 16),
              ZedHero(
                prefs: settings.zedPrefs,
                spec: _zedSpec(
                  l: l,
                  status: status,
                  on: on,
                  busy: core.switchingProxy,
                  connecting: connecting,
                  connected: connected,
                  stateLabel: label,
                  hint: press,
                  onToggle: () => status.totalAccounts == 0
                      ? _openAccounts(context, core, settings, onOpenAccounts)
                      : runShowingErrors(context, () => _toggle(on)),
                ),
                upText: formatRate(status.traffic?.upRate ?? 0),
                downText: formatRate(status.traffic?.downRate ?? 0),
                upRate: (status.traffic?.upRate ?? 0).toDouble(),
                downRate: (status.traffic?.downRate ?? 0).toDouble(),
                onOpenServers: onOpenServers,
                onOpenAccounts: onOpenAccounts,
                serversLabel: l.navServers,
                accountsLabel: l.navAccounts,
              ),
              const SizedBox(height: 8),
              if (connected)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HomeDelay(core: core, palette: p),
                    if (ip.isNotEmpty)
                      _HomePill(
                        palette: p,
                        child: Text(
                          '${l.publicIp} ${ltr(ip)}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: p.muted,
                          ),
                        ),
                      ),
                    if (status.upstreamProxy.isNotEmpty)
                      _UpstreamProxyPill(
                        address: status.upstreamProxy,
                        palette: p,
                        onPressed: onOpenUpstreamProxy,
                      ),
                  ],
                )
              else if (failing || noNetwork || gaveUp)
                // Not connecting stands out from the ordinary hints.
                problem(
                  _ProblemBox(
                    text: noNetwork
                        ? l.noNetwork
                        : failure != null
                        ? failure.text
                        : failureCodeText(l, status.connectFailure),
                    color: p.error,
                    icon: Icons.error_outline_rounded,
                    tooltip: noNetwork ? '' : failure?.detail ?? '',
                  ),
                )
              else
                // A start failure's hint is general; the core's reason is
                // on a long press.
                Tooltip(
                  message:
                      !status.connectPending &&
                          status.state.phase == Phase.error
                      ? status.state.message
                      : '',
                  child: Text(
                    look.hint.isNotEmpty ? look.hint : press,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tapHintColor,
                    ),
                  ),
                ),
              // Where to find the proxy, on a line of its own under the delay.
              if (connected && proxyOnly && proxy != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: _HomePill(
                      palette: p,
                      child: Text(
                        '${l.modeProxyOnly} ${ltr('127.0.0.1:${portOf(proxy.listen) ?? 10810}')}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: p.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              if (failure?.code == Failure.unreachable &&
                  onOpenConnection != null)
                _ConnectionSettingsButton(onPressed: onOpenConnection!),
              if (failure?.code == Failure.upstreamProxy &&
                  onOpenUpstreamProxy != null)
                _ConnectionSettingsButton(
                  onPressed: onOpenUpstreamProxy!,
                  label: AppLocalizations.of(context).upstreamProxy,
                ),
              if (!connected &&
                  status.upstreamProxy.isNotEmpty &&
                  failure?.code != Failure.upstreamProxy)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: _UpstreamProxyPill(
                      address: status.upstreamProxy,
                      palette: p,
                      onPressed: onOpenUpstreamProxy,
                    ),
                  ),
                ),
              if (isLocationRefused(failure?.code ?? '') ||
                  (gaveUp && isLocationRefused(status.connectFailure)))
                _RecommendedLocationButton(core: core),
              if (connected && mismatch != null)
                problem(_ExitMismatchNote(text: mismatch)),
              if (canSwitch &&
                  status.systemProxySet &&
                  status.systemProxyTakenBy != null)
                problem(
                  _SystemProxyTakenNote(
                    core: core,
                    by: status.systemProxyTakenBy!,
                  ),
                ),
              if (status.state.proxyPortBlocked) ...[
                const SizedBox(height: 12),
                Center(
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      final port = await showPortDialog(
                        context,
                        taken: status.state.address,
                      );
                      if (port != null && context.mounted) {
                        await runShowingErrors(
                          context,
                          () => core.setProxyPort(port),
                        );
                      }
                    },
                    icon: const Icon(Icons.settings_ethernet_rounded),
                    label: Text(l.changePort),
                  ),
                ),
              ],
              if (running &&
                  proxy != null &&
                  !canSwitch &&
                  sharedWithLan(proxy.listen)) ...[
                const SizedBox(height: 10),
                Center(child: _LanChip(port: portOf(proxy.listen) ?? 10810)),
              ],
              const Spacer(),
              if (settings.showAppModeSwitch && Platform.isAndroid) ...[
                ListenableBuilder(
                  listenable: Listenable.merge([
                    AndroidCore.mode,
                    AndroidCore.appRoutingMode,
                    AndroidCore.selectedAppsCount,
                  ]),
                  builder: (context, _) {
                    final mode = AndroidCore.mode.value;
                    final routing = AndroidCore.appRoutingMode.value;
                    final selected = mode == 'proxy' ? 'proxy' : routing;
                    final port =
                        portOf(proxy?.listen ?? '') ??
                        portOf(status.state.address) ??
                        10810;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: _ModeSwitch(
                            palette: p,
                            accent: accent,
                            selected: selected,
                            onSelected: core.switchingProxy
                                ? null
                                : (newMode) async {
                                    if (newMode == 'proxy') {
                                      await runShowingErrors(
                                        context,
                                        () => AndroidCore.setMode('proxy'),
                                      );
                                    } else if (newMode == 'selected') {
                                      if (AndroidCore.mode.value != 'vpn') {
                                        await runShowingErrors(
                                          context,
                                          () => AndroidCore.setMode('vpn'),
                                        );
                                      }
                                      await AndroidCore.setRoutingEnabled(true);
                                      AndroidCore.appRoutingMode.value =
                                          'selected';
                                      try {
                                        final r =
                                            await AndroidCore.appRouting();
                                        AndroidCore.selectedAppsCount.value =
                                            r.chosenCount;
                                      } catch (_) {}
                                    } else if (newMode == 'all') {
                                      if (AndroidCore.mode.value != 'vpn') {
                                        await runShowingErrors(
                                          context,
                                          () => AndroidCore.setMode('vpn'),
                                        );
                                      }
                                      await AndroidCore.setRoutingEnabled(
                                        false,
                                      );
                                      AndroidCore.appRoutingMode.value = 'all';
                                    }
                                  },
                            onTapSelected: (modeValue) {
                              if (modeValue == 'proxy') {
                                _openPortSettings(context, status);
                              } else if (modeValue == 'all') {
                                _openAllAppsSettings();
                              }
                            },
                            modes: [
                              (
                                value: 'all',
                                icon: Icons.public_rounded,
                                label: l.modeAllApps,
                                tooltip: l.modeAllAppsHint,
                              ),
                              (
                                value: 'selected',
                                icon: Icons.apps_rounded,
                                label: l.modeSelectedApps,
                                tooltip: l.modeSelectedAppsHint,
                              ),
                              (
                                value: 'proxy',
                                icon: Icons.settings_ethernet_rounded,
                                label: l.modeProxy,
                                tooltip: '${l.proxyPort}: $port',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (selected == 'proxy')
                          Center(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _openPortSettings(context, status),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: ShapeDecoration(
                                  color: p.card,
                                  shape: StadiumBorder(
                                    side: BorderSide(color: p.cardBorder),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 14,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${l.proxyPort}: $port',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: p.text,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 13,
                                      color: p.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (selected == 'selected')
                          Center(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _openBypassApps(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: ShapeDecoration(
                                  color: p.card,
                                  shape: StadiumBorder(
                                    side: BorderSide(color: p.cardBorder),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.apps_rounded,
                                      size: 14,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l.selectedAppsCount(
                                        '${AndroidCore.selectedAppsCount.value}',
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: p.text,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_left_rounded,
                                      size: 16,
                                      color: p.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Center(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _openAllAppsSettings,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  l.allTrafficThroughVpn,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: p.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ] else if (settings.showAppModeSwitch &&
                  (status.systemProxySupported || status.tunSupported)) ...[
                Center(
                  child: _ModeSwitch(
                    palette: p,
                    accent: accent,
                    selected: connectionModeShown(status),
                    onSelected: core.switchingProxy || core.installingTun
                        ? null
                        : (mode) => chooseConnectionMode(context, core, mode),
                    modes: [
                      (
                        value: 'clear',
                        icon: Icons.settings_ethernet_rounded,
                        label: l.modeProxy,
                        tooltip: running && proxy != null
                            ? '${l.proxyServiceActive} · ${proxy.listen}'
                            : '',
                      ),
                      if (status.systemProxySupported)
                        (
                          value: 'set',
                          icon: Icons.computer_rounded,
                          label: l.systemProxy,
                          tooltip: '',
                        ),
                      if (status.tunSupported)
                        (
                          value: 'tun',
                          icon: Icons.vpn_lock_rounded,
                          label: l.modeTun,
                          tooltip: '',
                        ),
                    ],
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
                  style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                ),
                TunNote(
                  core: core,
                  box: (text, tooltip) => _ProblemBox(
                    text: text,
                    color: StatusColors.busy,
                    icon: Icons.warning_amber_rounded,
                    tooltip: tooltip,
                  ),
                ),
              ],
              SizedBox(height: short ? 12 : 20),
              _UpdateNotice(core: core, settings: settings, palette: p),
              _UdpNotice(status: status, settings: settings, palette: p),
              _Notices(notices: homeNotices(status.notices)),
              _LowQuotaNotice(
                core: core,
                status: status,
                settings: settings,
                connected: connected,
                palette: p,
              ),
              if (sideBySide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showPlaceCard) ...[
                        Expanded(
                          child: _PlaceCard(
                            palette: p,
                            place: place,
                            accent: accent,
                            onTap: onOpenServers,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: _HomeData(
                          status: status,
                          palette: p,
                          onTap: onOpenAccounts,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (showPlaceCard) ...[
                  _PlaceCard(
                    palette: p,
                    place: place,
                    accent: accent,
                    onTap: onOpenServers,
                  ),
                  const SizedBox(height: 12),
                ],
                _HomeData(status: status, palette: p, onTap: onOpenAccounts),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A soft round light for the background.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.alpha});

  final Color color;
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

/// A frosted card on the home background.
/// The height of the home cards' content: the data card's ring; smaller
/// on the computer, whose controls above the cards are small.
double _homeCardContent(bool compact) => compact ? 46 : 62;

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.palette,
    required this.child,
    this.onTap,
    this.compact = false,
  });

  final _HomePalette palette;
  final Widget child;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      boxShadow: palette.dark
          ? null
          : [
              BoxShadow(
                color: const Color(0xFF2A3375).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
    ),
    child: Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: palette.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: compact
              ? const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10)
              : const EdgeInsetsDirectional.fromSTEB(16, 14, 10, 14),
          child: child,
        ),
      ),
    ),
  );
}

/// The real delay under the state; a tap tests again.
class _HomeDelay extends StatelessWidget {
  const _HomeDelay({required this.core, required this.palette});

  final CoreController core;
  final _HomePalette palette;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final test = core.lastTest;
    // The core settles a figure taken during the apps' rush before it
    // reports one (proxy.settledResponseMS), so what arrives here is
    // already the figure that holds and is shown as it is.
    final (text, color) = switch (test) {
      null => (l.testConnection, palette.muted),
      final t when !t.ok => (l.testFailed, palette.error),
      final t => (l.milliseconds(t.responseMs), delayColor(t.responseMs)),
    };
    return Tooltip(
      message: '${l.realDelay} · ${l.testConnection}',
      child: Material(
        color: palette.card,
        shape: StadiumBorder(side: BorderSide(color: palette.cardBorder)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: core.testing
              ? null
              : () => runShowingErrors(context, core.runTest),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (core.testing)
                  const SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  Icon(Icons.bolt_rounded, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  text,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
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

/// The switch: an orb in the state's color with a glow and a thin ring,
/// over wavy contour lines. It stays still: an endless animation redraws the
/// window every frame, and kept a CPU core busy even with the window hidden
/// in the tray.
/// The data used of the active account: a ring that fills as it is used,
/// in the quota's color, and the amount in large type.
class _HomeData extends StatelessWidget {
  const _HomeData({
    required this.status,
    required this.palette,
    this.onTap,
    this.compact = false,
  });

  final CoreStatus status;
  final _HomePalette palette;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = palette;
    final muted = theme.textTheme.bodySmall?.copyWith(color: p.muted);
    final a = status.activeAccount;
    final usage = a?.usage;
    Widget body;
    if (a != null && usage != null && usage.unlimited) {
      // The same shape as a quota that has a limit, so the card keeps its
      // height and its weight on the page: the ring is simply full, with the
      // sign for "no limit" in the middle instead of a percentage.
      body = Row(
        children: [
          SizedBox.square(
            dimension: _homeCardContent(compact),
            child: CustomPaint(
              painter: _QuotaRing(
                value: 1,
                color: theme.colorScheme.primary,
                track: p.text.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Icon(
                  Icons.all_inclusive_rounded,
                  size: compact ? 20 : 26,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.monthlyData, style: muted),
                Text(
                  l.unlimited,
                  style:
                      (compact
                              ? theme.textTheme.titleSmall
                              : theme.textTheme.titleMedium)
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (a == null || usage == null) {
      body = Row(
        children: [
          Icon(
            a == null
                ? Icons.person_add_alt_rounded
                : Icons.all_inclusive_rounded,
            color: p.muted,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              a == null ? l.noActiveAccount : l.quotaNotRead,
              style: theme.textTheme.titleMedium?.copyWith(color: p.text),
            ),
          ),
        ],
      );
    } else {
      final used = usage.usedBytes.clamp(0, usage.limitBytes);
      final fraction = usage.limitBytes == 0 ? 0.0 : used / usage.limitBytes;
      final color = quotaColor(fraction * 100, status.thresholdPercent);
      body = Row(
        children: [
          SizedBox.square(
            dimension: _homeCardContent(compact),
            child: CustomPaint(
              painter: _QuotaRing(
                value: fraction,
                color: color,
                track: p.text.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Text(
                  ltr('${(fraction * 100).round()}%'),
                  style:
                      (compact
                              ? theme.textTheme.labelMedium
                              : theme.textTheme.titleSmall)
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: p.text,
                          ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.dataUsedTitle, style: muted),
                Text(
                  formatBytes(used),
                  style:
                      (compact
                              ? theme.textTheme.titleLarge
                              : theme.textTheme.headlineSmall)
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: p.text,
                          ),
                ),
                Text(
                  [
                    l.dataLeftOf(formatBytes(usage.limitBytes)),
                    if (usage.resetAt != null)
                      l.resets(formatDate(l, usage.resetAt!)),
                  ].join(' · '),
                  style: muted,
                ),
              ],
            ),
          ),
        ],
      );
    }
    return _HomeCard(
      palette: p,
      onTap: onTap,
      compact: compact,
      child: Row(
        children: [
          Expanded(child: body),
          Icon(Icons.chevron_right_rounded, color: p.muted),
        ],
      ),
    );
  }
}

class _QuotaRing extends CustomPainter {
  _QuotaRing({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value.clamp(0.0, 1.0),
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_QuotaRing old) =>
      old.value != value || old.color != color || old.track != track;
}

/// The proxy's address on the local network, for other devices; a tap
/// copies it.
class _LanChip extends StatefulWidget {
  const _LanChip({required this.port});

  final int port;

  @override
  State<_LanChip> createState() => _LanChipState();
}

class _LanChipState extends State<_LanChip> {
  String? _ip;

  @override
  void initState() {
    super.initState();
    lanAddress().then((ip) {
      if (mounted) setState(() => _ip = ip);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ip = _ip;
    if (ip == null) return const SizedBox.shrink();
    final address = '$ip:${widget.port}';
    return ActionChip(
      avatar: const Icon(Icons.lan_outlined, size: 18),
      label: Text(l.lanAddress(ltr(address))),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: address));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.copied(address)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

/// Refusals dismissed in this session, by [Notice.key]; a newer refusal of
/// the same kind shows again.
final _dismissedNotices = <String>{};

/// Notes on requests the proxy refused in the last minutes: a port
/// Mozilla's proxy does not connect to, or UDP.
class _Notices extends StatefulWidget {
  const _Notices({required this.notices});

  final List<Notice> notices;

  @override
  State<_Notices> createState() => _NoticesState();
}

class _NoticesState extends State<_Notices> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shown = [
      for (final n in widget.notices)
        if (!_dismissedNotices.contains(n.key) &&
            (n.kind == 'port' || n.kind == 'command'))
          n,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final n in shown)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
              decoration: BoxDecoration(
                color: StatusColors.busy.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: StatusColors.busy.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: StatusColors.busy,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.kind == 'port'
                              ? l.noticePort(n.detail)
                              : l.noticeCommand,
                          style: theme.textTheme.bodySmall,
                        ),
                        if (n.last != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            [
                              l.noticeTimes(n.count, formatAgo(l, n.last!)),
                              if (n.hosts.isNotEmpty) n.hosts.join(', '),
                            ].join(' · '),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.dismiss,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () =>
                        setState(() => _dismissedNotices.add(n.key)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A newer version on GitHub. The desktop apps (Windows, Linux, macOS)
/// install it themselves: Update downloads it (its progress shows here),
/// then the app closes and opens again as the new version; on Android it
/// downloads here and Update opens Android's installer (or, with Update in
/// the app off, Download opens the browser; Updates).
/// After an update, what it did. Closed, a version's notice stays away
/// until a later version.
class _UpdateNotice extends StatelessWidget {
  const _UpdateNotice({
    required this.core,
    required this.settings,
    required this.palette,
  });

  final CoreController core;
  final AppSettings settings;
  final _HomePalette palette;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      Updates.available,
      Updates.failure,
      Updates.resultSeen,
    ]),
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final update = core.status?.update;
      final release = Updates.available.value;
      final last = update?.last;
      if (last != null &&
          !Updates.resultSeen.value &&
          release?.mandatory != true) {
        return _UpdateBanner(
          palette: palette,
          icon: last.ok ? Icons.check_circle_rounded : Icons.history_rounded,
          text: last.ok ? l.updateDone(last.to) : l.updateRolledBack(last.to),
          tooltip: last.error,
          problem: !last.ok,
          onClose: () => Updates.resultSeen.value = true,
        );
      }
      if (release == null ||
          (!release.mandatory && release.version == settings.dismissedUpdate)) {
        return const SizedBox.shrink();
      }
      final VoidCallback? dismiss = release.mandatory
          ? null
          : () => settings.update(dismissedUpdate: release.version);
      if (update == null) {
        return _UpdateBanner(
          palette: palette,
          icon: Icons.system_update_rounded,
          text: release.mandatory
              ? l.updateRequired(release.version)
              : l.updateAvailable(release.version),
          problem: release.mandatory,
          action: release.url.isEmpty
              ? null
              : (
                  label: l.download,
                  icon: Icons.download_rounded,
                  onPressed: () => openDownload(context, release),
                ),
          onClose: dismiss,
        );
      }
      final mine = update.version == release.version;
      if (mine && (update.downloading || update.installing)) {
        return _UpdateBanner(
          palette: palette,
          icon: Icons.downloading_rounded,
          text: update.downloading
              ? l.updateDownloading(release.version)
              : l.updateInstalling(release.version),
          busy: true,
          progress: update.downloading ? update.progress : null,
        );
      }
      final failure =
          Updates.failure.value ??
          (mine && update.failed ? update.error : null);
      if (failure != null) {
        return _UpdateBanner(
          palette: palette,
          icon: Icons.error_outline_rounded,
          text: l.updateFailed(release.version),
          tooltip: failure,
          problem: true,
          action: (
            label: l.tryAgain,
            icon: Icons.refresh_rounded,
            onPressed: () => Updates.update(release),
          ),
          onClose: dismiss,
        );
      }
      return _UpdateBanner(
        palette: palette,
        icon: Icons.system_update_rounded,
        problem: release.mandatory,
        text: release.mandatory
            ? l.updateRequired(release.version)
            : mine && update.ready
            ? l.updateReady(release.version)
            : l.updateAvailable(release.version),
        action: (
          label: l.updateNow,
          icon: Icons.system_update_alt_rounded,
          onPressed: () => Updates.update(release),
        ),
        onClose: dismiss,
      );
    },
  );
}

/// The update notice's look: a rounded bar in the connected color (amber
/// for a problem, with the core's reason on hover), a button, a close
/// button, and a progress bar under the text while busy.
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({
    required this.palette,
    required this.icon,
    required this.text,
    this.tooltip = '',
    this.problem = false,
    this.action,
    this.busy = false,
    this.progress,
    this.onClose,
  });

  final _HomePalette palette;
  final IconData icon;
  final String text;
  final String tooltip;
  final bool problem;
  final ({String label, IconData icon, VoidCallback onPressed})? action;

  /// A bar under the text: the download's [progress], or under way
  /// (null).
  final bool busy;
  final double? progress;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = palette;
    final color = problem ? StatusColors.busy : p.connected;
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color.withValues(alpha: p.dark ? 0.16 : 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            14,
            6,
            onClose == null ? 14 : 6,
            6,
          ),
          child: Row(
            children: [
              // The notice with its button is one place to choose: a
              // remote's down arrow from the switch reaches it (the button
              // alone stands aside, out of the arrow's line), and OK runs
              // the button's action; right goes on to close.
              Expanded(
                child: InkWell(
                  onTap: action?.onPressed,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Tooltip(
                                message: tooltip,
                                child: Text(
                                  text,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: p.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (busy) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 4,
                                    color: color,
                                    backgroundColor: color.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: 8),
                        // Solid, in the banner's color: the one thing to
                        // press (focus goes to the whole notice).
                        ExcludeFocus(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              // From the theme, for its font (Vazirmatn in
                              // Persian): a bare style would replace it.
                              textStyle: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: action.onPressed,
                            icon: Icon(action.icon, size: 18),
                            label: Text(action.label),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: l.dismiss,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
                  onPressed: onClose,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TUN mode refused a program's UDP that looks like a call or a game (on a port
/// Mozilla does not carry): the program by name. Sending its UDP directly is
/// chosen in the TUN settings, on purpose: a button here could be pressed without
/// knowing what it gives away. Once seen, the card goes after a minute, and stays
/// away while the same program is the one refused and the TUN runs.
class _UdpNotice extends StatefulWidget {
  const _UdpNotice({
    required this.status,
    required this.settings,
    required this.palette,
  });

  final CoreStatus status;
  final AppSettings settings;
  final _HomePalette palette;

  @override
  State<_UdpNotice> createState() => _UdpNoticeState();
}

class _UdpNoticeState extends State<_UdpNotice> {
  static const _showFor = Duration(seconds: 60);

  /// The program the card is out for, and whether its minute is over; the
  /// minute starts when the card can first be seen (the window is shown, the
  /// app in front), also when the home page is built again meanwhile.
  static String? _shownFor;
  static bool _over = false;
  static Timer? _minute;
  static final _changed = ValueNotifier(0);

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _changed.addListener(_rebuild);
    // Shown from the tray, or the app brought to the front: seen now.
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _rebuild());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _changed.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// Whether the user can see the home page now.
  static bool get _seen {
    final state = WidgetsBinding.instance.lifecycleState;
    return (state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive) &&
        !Updates.windowHidden();
  }

  /// Whether to show the card for [program] ("" for none) now.
  bool _visible(String program) {
    if (program.isEmpty) {
      // The TUN stopped, or the program skips the VPN now: a later refusal
      // shows again.
      _shownFor = null;
      _over = false;
      _minute?.cancel();
      _minute = null;
      return false;
    }
    if (program != _shownFor) {
      _shownFor = program;
      _over = false;
      _minute?.cancel();
      _minute = null;
    }
    if (!_over && _minute == null && _seen) {
      _minute = Timer(_showFor, () {
        _over = true;
        _changed.value++;
      });
    }
    return !_over;
  }

  /// A program by the name people know: without ".exe".
  static String _label(String program) => program.toLowerCase().endsWith('.exe')
      ? program.substring(0, program.length - 4)
      : program;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) {
      final status = widget.status, settings = widget.settings;
      final tun = status.tun;
      final refused = status.tunMode && tun != null && tun.on
          ? tun.refusedUdp
          : '';
      if (!_visible(refused) ||
          !tun!.programsSupported ||
          !settings.udpNotice) {
        return const SizedBox.shrink();
      }
      final program = refused;
      final l = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final p = widget.palette;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: StatusColors.busy.withValues(alpha: p.dark ? 0.16 : 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: StatusColors.busy.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 6, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: StatusColors.busy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.udpNoticeBody(ltr(_label(program))),
                    style: theme.textTheme.bodyMedium?.copyWith(color: p.text),
                  ),
                ),
                const SizedBox(width: 8),
                // The style starts from the theme, for its font.
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: p.muted,
                    visualDensity: VisualDensity.compact,
                    textStyle: theme.textTheme.labelLarge,
                  ),
                  onPressed: () => settings.update(udpNotice: false),
                  icon: const Icon(Icons.visibility_off_outlined, size: 18),
                  label: Text(l.dontShowAgain),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// When the user connects and the active account is nearly used up with
/// no other account to take over: adding an account gives another month's
/// data. Shown once per connection, for a minute; closed, it stays away for
/// a day.
class _LowQuotaNotice extends StatefulWidget {
  const _LowQuotaNotice({
    required this.core,
    required this.status,
    required this.settings,
    required this.connected,
    required this.palette,
  });

  final CoreController core;
  final CoreStatus status;
  final AppSettings settings;
  final bool connected;
  final _HomePalette palette;

  @override
  State<_LowQuotaNotice> createState() => _LowQuotaNoticeState();
}

class _LowQuotaNoticeState extends State<_LowQuotaNotice> {
  /// Below this much left, the account is running out.
  static const _left = 5 << 30;
  static const _showFor = Duration(seconds: 60);
  static const _quiet = Duration(hours: 24);

  /// The connection it was shown for (the proxy's start), and whether its
  /// minute is over: once per connection, also when the home page is
  /// built again meanwhile.
  static DateTime? _shownFor;
  static bool _started = false;
  static bool _over = false;
  static Timer? _minute;
  static final _changed = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _changed.addListener(_rebuild);
  }

  @override
  void dispose() {
    _changed.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  bool get _due {
    final active = widget.status.activeAccount;
    final usage = active?.usage;
    if (!widget.connected || active == null || usage == null) return false;
    if (usage.unlimited || usage.limitBytes == 0) return false;
    if (usage.remainingBytes >= _left) return false;
    // Another account that can take over: the app moves to it by itself.
    final others = widget.core.accounts?.accounts ?? const <Account>[];
    final spare = others.any(
      (a) =>
          a.id != active.id &&
          a.enabled &&
          a.status == AccountStatus.ready &&
          (a.usage?.unlimited == true ||
              (a.usage?.remainingBytes ?? 0) >= _left),
    );
    if (spare) return false;
    final closed = widget.settings.lowQuotaDismissedAt;
    return closed == null || DateTime.now().difference(closed) >= _quiet;
  }

  /// Whether to show it now; the minute starts at the first look of a
  /// connection.
  bool _visible() {
    if (!_due) return false;
    final connection = widget.status.proxy?.startedAt;
    if (!_started || _shownFor != connection) {
      _started = true;
      _shownFor = connection;
      _over = false;
      _minute?.cancel();
      _minute = Timer(_showFor, () {
        _over = true;
        _changed.value++;
      });
    }
    return !_over;
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible()) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = widget.palette;
    final usage = widget.status.activeAccount!.usage!;
    String rounded(int bytes) => formatBytes(bytes).replaceAll('.0 ', ' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: StatusColors.busy.withValues(alpha: p.dark ? 0.16 : 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: StatusColors.busy.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.data_usage_rounded,
                      color: StatusColors.busy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.lowQuotaNotice(rounded(usage.limitBytes)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: p.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.close,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
                    onPressed: () {
                      widget.settings.update(
                        lowQuotaDismissedAt: DateTime.now(),
                      );
                      setState(() {});
                    },
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () =>
                      startAddAccount(context, widget.core, widget.settings),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(l.addAccount),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
