import 'dart:io';
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../app_settings.dart';
import '../../core/android_core.dart';
import '../../core/core_controller.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../signin_dialog.dart';
import '../overview_page.dart' show HomeFunctionStack;
import '../widgets.dart';
import 'zed_connect.dart';
import 'zed_kit.dart';

/// The four Zed design homes — Bento, Pixel, Old, Glass — over ONE
/// shared state derivation, exactly as ZedSecure's designs share one
/// settings/state model and differ only in their kits (§8). The state
/// derivation is the same one every home in this app has always used
/// (the shared helpers in widgets.dart): on from the engine's phase,
/// live only once a connection test confirms it. Nothing here decides
/// anything about the VPN; every action is the core's, through
/// [homePowerPressed].

class ZedHomeData {
  ZedHomeData(this.core, this.status, this.l, {this.phone = false});

  final CoreController core;
  final CoreStatus status;
  final AppLocalizations l;

  /// Built by the phone shell: the power's words are the phone's
  /// ("Tap to…"; a TV's remote "presses OK"), not the computer's.
  final bool phone;

  bool get on => engineOn(status);
  bool get live => connectionLive(status, core.lastTest);
  bool get busy =>
      !live &&
      (status.connectPending ||
          status.state.phase == Phase.starting ||
          status.state.phase == Phase.running ||
          status.state.phase == Phase.waiting ||
          core.switchingProxy);
  PhaseLook get look => PhaseLook.of(l, status);

  /// The connect control's word, the classic home's exact rule:
  /// Connecting while a connect is pending or the running proxy is
  /// still unconfirmed by a test; Connected once confirmed; otherwise
  /// the phase's own word (Disconnected, the failure's word…).
  String get stateLabel {
    final confirming =
        status.connectPending ||
        (status.proxyOn &&
            status.state.phase == Phase.running &&
            !status.confirmedBy(core.lastTest));
    return confirming
        ? l.stateConnecting
        : live
        ? l.stateConnected
        : look.label;
  }
  HomePlace get place => homeLocation(l, status, connected: live);
  bool get hasError => status.state.phase == Phase.error;
  String get errorText =>
      look.hint.isNotEmpty ? look.hint : status.state.message;
  DateTime? get since => live ? status.state.since : null;
  int? get pingMs {
    final t = core.lastTest;
    return t != null && t.ok ? t.responseMs : null;
  }

  List<Account> get accounts => core.accounts?.accounts ?? const [];

  ZedConnectState connectState(BuildContext context, VoidCallback? onOpenAccounts) =>
      ZedConnectState(
        on: on,
        busy: busy,
        live: live,
        label: stateLabel,
        tooltip: on
            ? (phone
                  ? (Platform.isAndroid && AndroidCore.isTv
                        ? l.tapToDisconnectTv
                        : l.tapToDisconnectPhone)
                  : l.tapToDisconnect)
            : (phone
                  ? (Platform.isAndroid && AndroidCore.isTv
                        ? l.tapToConnectTv
                        : l.tapToConnectPhone)
                  : l.tapToConnect),
        onToggle: () => homePowerPressed(
          context,
          core,
          onNoAccounts: () {
            if (onOpenAccounts != null) {
              onOpenAccounts();
            } else {
              showSignInDialog(context, core);
            }
          },
        ),
      );
}

typedef ZedHomeArgs = ({
  CoreController core,
  AppSettings settings,
  bool phone,
  VoidCallback onOpenServers,
  VoidCallback onOpenAccounts,
  VoidCallback? onOpenConnection,
  VoidCallback? onOpenUpstreamProxy,
});

Widget _trafficTiles(BuildContext context, ZedHomeData d, ZedPrefs prefs) {
  final t = d.status.traffic;
  Widget tile(IconData icon, String label, String value) => Expanded(
    child: ZedModule(
      prefs: prefs,
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
  return Row(
    children: [
      tile(Icons.arrow_downward_rounded, d.l.zedDownload, formatRate(t?.downRate ?? 0)),
      const SizedBox(width: 12),
      tile(Icons.arrow_upward_rounded, d.l.zedUpload, formatRate(t?.upRate ?? 0)),
    ],
  );
}

/// The session timer, ticking each second while live.
class _Elapsed extends StatefulWidget {
  const _Elapsed({required this.since, this.style});

  final DateTime? since;
  final TextStyle? style;

  @override
  State<_Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends State<_Elapsed> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Elapsed old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Ticks only while a session start exists to count from; with no
  /// session the widget renders nothing and must not rebuild every
  /// second for no reason.
  void _sync() {
    if (widget.since != null && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (widget.since == null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.since;
    if (since == null) return const SizedBox.shrink();
    final s = DateTime.now().difference(since).inSeconds.clamp(0, 1 << 31);
    String two(int v) => v.toString().padLeft(2, '0');
    final text =
        '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
    return Text(
      text,
      style: (widget.style ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// The classic home's functional stack (connection mode, TUN,
/// notices, quota, place/data cards) — shared verbatim with the Zed
/// homes so no home behaviour is dropped in the rebuild.
Widget _functionStack(ZedHomeArgs args) => HomeFunctionStack(
  core: args.core,
  settings: args.settings,
  onOpenServers: args.onOpenServers,
  onOpenAccounts: args.onOpenAccounts,
  onOpenConnection: args.onOpenConnection,
  onOpenUpstreamProxy: args.onOpenUpstreamProxy,
);

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          children[i],
        ],
      ],
    ),
  );
}

/// Bento home: a huge title, the connect control as the hub's hero
/// module, then the hub tiles — server, accounts, traffic, quota.
class ZedBentoHome extends StatelessWidget {
  const ZedBentoHome({super.key, required this.args});

  final ZedHomeArgs args;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = args.core.status!;
    final d = ZedHomeData(args.core, status, l, phone: args.phone);
    final prefs = args.settings.zed;
    return _HomeScaffold(
      children: [
        Text(
          l.appTitle,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        ZedModule(
          prefs: prefs,
          hero: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ZedConnectControl(
                prefs: prefs,
                state: d.connectState(context, args.onOpenAccounts),
              ),
              const SizedBox(height: 12),
              _Elapsed(
                since: d.since,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        _functionStack(args),
        _trafficTiles(context, d, prefs),
      ],
    );
  }
}

/// Pixel home: the hero connect core centred, then Material modules.
class ZedPixelHome extends StatelessWidget {
  const ZedPixelHome({super.key, required this.args});

  final ZedHomeArgs args;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = ZedHomeData(args.core, args.core.status!, l, phone: args.phone);
    final prefs = args.settings.zed;
    return _HomeScaffold(
      children: [
        const SizedBox(height: 12),
        Center(
          child: ZedConnectControl(
            prefs: prefs,
            state: d.connectState(context, args.onOpenAccounts),
          ),
        ),
        Center(
          child: _Elapsed(
            since: d.since,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        _functionStack(args),
        _trafficTiles(context, d, prefs),
      ],
    );
  }
}

/// Old home: the plain Material look — Old's full kit exists only for
/// Home in ZedSecure, and it is deliberately unadorned there too.
class ZedOldHome extends StatelessWidget {
  const ZedOldHome({super.key, required this.args});

  final ZedHomeArgs args;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = ZedHomeData(args.core, args.core.status!, l, phone: args.phone);
    final prefs = args.settings.zed;
    return _HomeScaffold(
      children: [
        PageTitle(l.appTitle),
        Center(
          child: ZedConnectControl(
            prefs: prefs,
            state: d.connectState(context, args.onOpenAccounts),
          ),
        ),
        _functionStack(args),
        _trafficTiles(context, d, prefs),
      ],
    );
  }
}

/// Glass home: glass modules over the shell's wallpaper (the shell
/// paints it — the wallpaper belongs to the scaffold, not the page).
class ZedGlassHome extends StatelessWidget {
  const ZedGlassHome({super.key, required this.args});

  final ZedHomeArgs args;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = ZedHomeData(args.core, args.core.status!, l, phone: args.phone);
    final prefs = args.settings.zed;
    // No page-level bottom inset for the floating dock: the phone
    // shell now reserves the dock's inset for every tab's viewport
    // (and the desktop shell has no floating dock at all).
    return _HomeScaffold(
      children: [
        const SizedBox(height: 8),
        Center(
          child: ZedConnectControl(
            prefs: prefs,
            state: d.connectState(context, args.onOpenAccounts),
          ),
        ),
        if (prefs.glassShowTimer)
          Center(
            child: _Elapsed(
              since: d.since,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        _functionStack(args),
        if (prefs.glassShowSpeed) _trafficTiles(context, d, prefs),
      ],
    );
  }
}

/// The home for the current design — the single switch the shells call.
class ZedHome extends StatelessWidget {
  const ZedHome({super.key, required this.args});

  final ZedHomeArgs args;

  @override
  Widget build(BuildContext context) => switch (args.settings.zed.design) {
    ZedDesign.bento => ZedBentoHome(args: args),
    ZedDesign.pixel => ZedPixelHome(args: args),
    ZedDesign.old => ZedOldHome(args: args),
    ZedDesign.glass => ZedGlassHome(args: args),
  };
}
