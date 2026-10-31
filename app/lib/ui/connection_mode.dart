import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/core_controller.dart';
import '../core/models.dart';
import '../core/tun_service.dart';
import '../l10n/app_localizations.dart';
import 'widgets.dart';

// The computer's connection mode (system_proxy.mode): proxy only, the
// system proxy, or TUN. TUN needs its service, which never starts with
// the computer: the app starts it whenever the mode is chosen (installing
// it the first time; the system asks for administrator permission only
// when the service is not already running); everything else is the
// core's.

/// Switches to [mode], making sure the TUN service runs first when TUN
/// is chosen. A declined prompt or a failed start leaves the mode as it
/// was, and says so.
Future<void> chooseConnectionMode(
  BuildContext context,
  CoreController core,
  String mode,
) async {
  if (mode == 'tun') {
    if (!await installTunService(context, core)) return;
    if (!context.mounted) return;
  }
  await runShowingErrors(context, () => core.setSystemProxy(mode));
}

/// The connection mode shown as chosen: "clear" (Proxy), "set" (System
/// proxy), or "tun"; one this computer does not have shows as Proxy.
String connectionModeShown(CoreStatus status) => switch (status.systemProxy) {
  'set' when status.systemProxySupported => 'set',
  'tun' when status.tunSupported => 'tun',
  _ => 'clear',
};

/// Makes sure the TUN service runs (installing it on the first use),
/// with the system's administrator prompt when it is not running; false,
/// after telling the user, when it was declined or failed. The TUN
/// note's install button uses it too: "install" there also covers a
/// service that is installed but not running.
Future<bool> installTunService(
  BuildContext context,
  CoreController core,
) async {
  final l = AppLocalizations.of(context);
  final result = await core.startTunService(prompt: l.tunInstallPrompt);
  if (!context.mounted) return result is TunServiceDone;
  switch (result) {
    case TunServiceDone():
      return true;
    case TunServiceCancelled():
      showError(context, l.tunInstallCancelled);
    case TunServiceFailed(:final error):
      showError(context, l.tunInstallFailed(error));
  }
  return false;
}

/// The hint under the mode choice: what the mode does, or that Windows'
/// prompt is waiting.
String connectionModeHint(
  AppLocalizations l,
  CoreStatus status, {
  required bool installing,
  required bool windows,
}) {
  if (installing) return l.tunInstallWaiting;
  if (status.tunMode) {
    return l.modeTunHint(switch (defaultTargetPlatform) {
      TargetPlatform.macOS => l.osMacos,
      TargetPlatform.linux => l.osLinux,
      _ => l.osWindows,
    });
  }
  return switch ((status.systemProxySet, windows)) {
    (true, true) => l.modeSystemProxyHint,
    (true, false) => l.modeSystemProxyHintOther,
    (false, _) => l.modeProxyHint,
  };
}

/// What the home page says while TUN mode is chosen but not on, and the
/// install button where installing helps; null when there is nothing to
/// say (TUN on, off, or another mode).
({String text, String detail, bool problem, bool install, bool again})? tunNote(
  AppLocalizations l,
  CoreStatus status,
) {
  final tun = status.tun;
  if (!status.tunMode || tun == null || status.state.phase == Phase.off) {
    return null;
  }
  if (tun.starting) {
    return (
      text: l.tunStarting,
      detail: '',
      problem: false,
      install: false,
      again: false,
    );
  }
  if (!tun.failed) return null;
  final (text, install, again) = switch (tun.code) {
    TunCode.missing => (l.tunMissing, true, false),
    TunCode.notRunning => (l.tunNotRunning, true, true),
    TunCode.outdated => (l.tunOutdated, true, true),
    TunCode.appOutdated => (l.tunAppOutdated, false, false),
    TunCode.busy => (l.tunBusy, false, false),
    TunCode.lost => (l.tunLost, false, false),
    _ => (l.tunFailed, false, false),
  };
  return (
    text: text,
    detail: tun.message,
    problem: true,
    install: install,
    again: again,
  );
}

/// A connection mode in [ConnectionModeSelector]; an empty tooltip
/// shows none.
typedef ConnectionModeOption = ({
  String value,
  IconData icon,
  String label,
  String tooltip,
});

/// The connection modes as one rounded track with no lines between them:
/// the chosen mode sits on a pill that slides to the one tapped. The
/// modes are equally wide (the widest one's width), and the whole track
/// shrinks to fit a narrow window. A tap on the chosen mode changes
/// nothing.
///
/// This is the one selector every home design shows — the classic
/// desktop home's switch, shared — over the colors the design gives it:
/// Proxy, System proxy (where the computer has it), TUN (where it has
/// it), in that order. Changing the mode (chooseConnectionMode) keeps
/// the proxy running and connected.
class ConnectionModeSelector extends StatelessWidget {
  const ConnectionModeSelector({
    super.key,
    required this.core,
    required this.status,
    required this.card,
    required this.cardBorder,
    required this.text,
    required this.muted,
    required this.accent,
  });

  final CoreController core;
  final CoreStatus status;

  /// The track's colors, in the design's own palette.
  final Color card;
  final Color cardBorder;
  final Color text;
  final Color muted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final proxy = status.proxy;
    final running = status.state.phase == Phase.running;
    final modes = <ConnectionModeOption>[
      (
        value: 'clear',
        icon: Icons.settings_ethernet_rounded,
        label: l.modeProxy,
        // Where apps set up by hand find the proxy, which always runs.
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
    ];
    final selected = connectionModeShown(status);
    final onSelected = core.switchingProxy || core.installingTun
        ? null
        : (String mode) => chooseConnectionMode(context, core, mode);
    final n = modes.length;
    final index = modes.indexWhere((m) => m.value == selected);
    final still = MediaQuery.of(context).disableAnimations;
    Widget option(ConnectionModeOption m) {
      final chosen = m.value == selected;
      final color = chosen ? text : muted;
      Widget child = InkWell(
        customBorder: const StadiumBorder(),
        onTap: onSelected == null || chosen ? null : () => onSelected(m.value),
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
            color: card,
            shape: StadiumBorder(side: BorderSide(color: cardBorder)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            // The row is as wide as its widest mode times their number
            // (each mode Expanded under IntrinsicWidth), so the pill is
            // one mode wide wherever it is.
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
                  // A line between two modes, so each reads as a button
                  // of its own; none beside the pill, which marks its
                  // mode.
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
                                            color: muted.withValues(
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

/// The TUN mode's note on the home page: a line while it starts, an amber
/// box (the core's reason on hover) when it does not run, with Install or
/// Install again where that helps.
class TunNote extends StatelessWidget {
  const TunNote({super.key, required this.core, required this.box});

  final CoreController core;

  /// Builds the amber box (the home page's own).
  final Widget Function(String text, String tooltip) box;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = core.status;
    final note = status == null ? null : tunNote(l, status);
    if (note == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    if (!note.problem) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          note.text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: StatusColors.busy,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final busy = core.installingTun || core.removingTun;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          box(note.text, note.detail),
          if (note.install) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: busy ? null : () => installTunService(context, core),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(note.again ? l.tunInstallAgain : l.tunInstall),
            ),
          ],
        ],
      ),
    );
  }
}
