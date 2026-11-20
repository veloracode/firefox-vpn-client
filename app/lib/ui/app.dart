import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../app_settings.dart';
import '../core/android_core.dart';
import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'about_page.dart';
import 'announcement_panel.dart';
import 'accounts_page.dart';
import 'focus_ring.dart';
import 'format.dart';
import 'logs_page.dart';
import 'mobile_shell.dart';
import 'port_dialog.dart';
import 'servers_page.dart';
import 'settings_page.dart';
import 'welcome_page.dart';
import 'widgets.dart';
import 'zed/zed_glass.dart';
import 'zed/zed_home.dart';
import 'zed/zed_motion.dart';
import 'zed/zed_theme.dart';

/// The app's theme is the Zed design system's: four designs over the
/// one settings model (see zed/zed_theme.dart).
ThemeData _theme(Brightness brightness, Locale locale, ZedPrefs prefs) =>
    ZedTheme.build(brightness, locale, prefs);

class VpnApp extends StatelessWidget {
  const VpnApp({
    super.key,
    required this.core,
    required this.settings,
    this.navigatorKey,
  });

  final CoreController core;
  final AppSettings settings;
  final GlobalKey<NavigatorState>? navigatorKey;

  static const localizationsDelegates = [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, _) =>
          AppSettings.localeOf(AppSettings.languageForList(locales)),
      localizationsDelegates: localizationsDelegates,
      // The theme depends on the resolved language for its font.
      builder: (context, child) {
        final locale = Localizations.localeOf(context);
        final dark = switch (settings.themeMode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        return Theme(
          data: _theme(
            dark ? Brightness.dark : Brightness.light,
            locale,
            settings.zed,
          ),
          // A clear ring around what a remote or the keyboard chose.
          child: FocusRing(
            atStart: Platform.isAndroid && AndroidCore.isTv,
            child: child!,
          ),
        );
      },
      home: Shell(core: core, settings: settings),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.core, required this.settings});

  final CoreController core;
  final AppSettings settings;

  @override
  State<Shell> createState() => _ShellState();
}

enum _Page { overview, servers, accounts, settings, logs, about }

class _ShellState extends State<Shell> {
  _Page _page = _Page.overview;

  /// The last page the switcher showed and the direction of the most
  /// recent change (tab-order sign, flipped for RTL) — the motion
  /// system enters a page from the side its destination sits on.
  _Page? _lastPage;
  double _pageDirection = 1;

  /// The settings section the home page opened (Connection), until another
  /// page is chosen.
  SettingsSection? _settingsOpening;

  @override
  void initState() {
    super.initState();
    AndroidCore.homeRequests.addListener(_openHome);
  }

  void _openHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _page = _Page.overview;
      _settingsOpening = null;
    });
  }

  @override
  void dispose() {
    AndroidCore.homeRequests.removeListener(_openHome);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.core,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final core = widget.core;
      final status = core.status;
      final needsAttention = (core.accounts?.accounts ?? const [])
          .where((a) => a.enabled && a.needsSignIn)
          .length;
      if (widget.settings.firstRun && status != null) {
        return WelcomePage(core: core, settings: widget.settings);
      }
      final pages = [
        _Page.overview,
        _Page.servers,
        _Page.accounts,
        _Page.settings,
        _Page.logs,
        _Page.about,
      ];
      final page = pages.contains(_page) ? _page : _Page.overview;
      Widget accountsIcon(IconData icon) => Badge(
        isLabelVisible: needsAttention > 0,
        label: Text('$needsAttention'),
        child: Icon(icon),
      );
      // Each page's icons and name, for the side menu and the bottom bar.
      final items = [
        for (final page in pages)
          switch (page) {
            _Page.overview => (
              const Icon(Icons.dashboard_outlined),
              const Icon(Icons.dashboard_rounded),
              l.navOverview,
            ),
            _Page.servers => (
              const Icon(Icons.public_outlined),
              const Icon(Icons.public_rounded),
              l.navServers,
            ),
            _Page.accounts => (
              accountsIcon(Icons.people_outline_rounded),
              accountsIcon(Icons.people_rounded),
              l.navAccounts,
            ),
            _Page.settings => (
              const Icon(Icons.settings_outlined),
              const Icon(Icons.settings_rounded),
              l.navSettings,
            ),
            _Page.logs => (
              const Icon(Icons.receipt_long_outlined),
              const Icon(Icons.receipt_long_rounded),
              l.navLogs,
            ),
            _Page.about => (
              const Icon(Icons.info_outline_rounded),
              const Icon(Icons.info_rounded),
              l.navAbout,
            ),
          },
      ];
      final content = Column(
        children: [
          if (core.unavailable != null && status != null) const _LostBanner(),
          Expanded(
            child: status == null
                ? _NoCore(core: core)
                : switch (page) {
                    // The home is the current Zed design's kit (Bento,
                    // Pixel, Old, Glass — see zed/zed_home.dart); its
                    // modules open the pages beside it. The accounts
                    // page follows the same rule as before the rebuild:
                    // the plain Material page for Old, the rich page
                    // for the other designs.
                    _Page.overview => ZedHome(
                      args: (
                        core: core,
                        settings: widget.settings,
                        phone: false,
                        onOpenServers: () =>
                            setState(() => _page = _Page.servers),
                        onOpenAccounts: () =>
                            setState(() => _page = _Page.accounts),
                        onOpenConnection: () => setState(() {
                          _page = _Page.settings;
                          _settingsOpening = SettingsSection.connection;
                        }),
                        onOpenUpstreamProxy: () => setState(() {
                          _page = _Page.settings;
                          _settingsOpening = SettingsSection.upstreamProxy;
                        }),
                      ),
                    ),
                    _Page.servers => ServersPage(
                      core: core,
                      settings: widget.settings,
                    ),
                    // One accounts page for every design: the complete
                    // one (quota bars, switching, the backup menu). The
                    // previous reskin's accounts page dropped the backup
                    // menu; nothing is dropped in this rebuild.
                    _Page.accounts => AccountsPage(
                      core: core,
                      settings: widget.settings,
                    ),
                    _Page.settings => SettingsPage(
                      key: ValueKey(_settingsOpening),
                      core: core,
                      settings: widget.settings,
                      opening: _settingsOpening,
                      onOpenLogs: () => setState(() => _page = _Page.logs),
                    ),
                    _Page.logs => LogsPage(
                      core: core,
                      settings: widget.settings,
                    ),
                    _Page.about => AboutPage(core: core),
                  },
          ),
        ],
      );
      // The page area goes through the motion system; the rail stays
      // OUTSIDE the transition (the MainScaffold rule). Glass paints
      // its wallpaper behind the page area here — the wallpaper belongs
      // to the scaffold, never to a page.
      if (_lastPage != _page) {
        final delta = _page.index - (_lastPage ?? _page).index;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        _pageDirection = (delta < 0 ? -1.0 : 1.0) * (rtl ? -1.0 : 1.0);
        _lastPage = _page;
      }
      final switched = ZedPageSwitcher(
        prefs: widget.settings.zed,
        reduceMotion: !widget.settings.animationsEnabled ||
              MediaQuery.disableAnimationsOf(context),
        direction: _pageDirection,
        child: KeyedSubtree(key: ValueKey(page), child: content),
      );
      // A maximized window: the pages stay as wide as reads well, so
      // non-home pages are framed to a reading width — but only the
      // page content is framed; the Glass wallpaper is the scaffold's
      // background and always keeps the full size.
      final framed = page == _Page.overview || status == null
          ? switched
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: switched,
              ),
            );
      final pageArea = widget.settings.zed.design == ZedDesign.glass
          ? Stack(
              children: [
                Positioned.fill(
                  child: GlassWallpaperView(
                    prefs: widget.settings.zed,
                    dark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
                framed,
              ],
            )
          : framed;
      void select(int i) => setState(() {
        _page = pages[i];
        _settingsOpening = null;
      });
      // Android (a phone, or a tablet in either orientation) and a narrow
      // window: the phone layout, Home and Settings. The computer layout
      // offers computer-only choices, such as Windows' system proxy.
      if (Platform.isAndroid || MediaQuery.sizeOf(context).width < 640) {
        return MobileShell(
          core: core,
          settings: widget.settings,
          banner: core.unavailable != null && status != null
              ? const _LostBanner()
              : null,
          noCore: status == null ? _NoCore(core: core) : null,
        );
      }
      return Scaffold(
        body: AnnouncementOverlay(
          settings: widget.settings,
          onOpenUpdates: () => setState(() => _page = _Page.about),
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: pages.indexOf(page),
                onDestinationSelected: select,
                // Icons with their names beside them.
                extended: true,
                minExtendedWidth: 190,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Row(
                    children: [
                      const AppLogo(size: 34),
                      const SizedBox(width: 10),
                      Text(
                        l.appTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                destinations: [
                  for (final (icon, selected, label) in items)
                    NavigationRailDestination(
                      icon: icon,
                      selectedIcon: selected,
                      label: Text(label),
                    ),
                ],
                // The traffic at the bottom of the menu; in a short window the
                // pages above it scroll rather than run under it.
                trailing: _TrafficPanel(traffic: status?.traffic),
                trailingAtBottom: true,
                scrollable: true,
              ),
              // The page area (already framed to a reading width above
              // for non-home pages; the wallpaper inside it is not).
              Expanded(child: pageArea),
            ],
          ),
        ),
      );
    },
  );
}

/// The side menu's traffic: the speed now and the total since the core
/// started, through Mozilla, up and down.
class _TrafficPanel extends StatelessWidget {
  const _TrafficPanel({required this.traffic});

  final Traffic? traffic;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = traffic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: SizedBox(
        width: 166,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TrafficCard(
              title: l.liveTraffic,
              up: formatRate(t?.upRate ?? 0),
              down: formatRate(t?.downRate ?? 0),
            ),
            const SizedBox(height: 8),
            _TrafficCard(
              title: l.totalTraffic,
              up: formatBytes(t?.up ?? 0),
              down: formatBytes(t?.down ?? 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({
    required this.title,
    required this.up,
    required this.down,
  });

  final String title;
  final String up;
  final String down;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget line(IconData icon, Color color, String text) => Row(
      children: [
        Icon(icon, size: 14, color: color),
        const Spacer(),
        Text(text, style: value),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          line(Icons.arrow_upward_rounded, StatusColors.good, up),
          line(Icons.arrow_downward_rounded, theme.colorScheme.primary, down),
        ],
      ),
    );
  }
}

class _LostBanner extends StatelessWidget {
  const _LostBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: StatusColors.bad.withValues(alpha: 0.14),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.link_off_rounded, size: 18, color: StatusColors.bad),
        const SizedBox(width: 10),
        Expanded(child: Text(AppLocalizations.of(context).coreLost)),
      ],
    ),
  );
}

class _NoCore extends StatelessWidget {
  const _NoCore({required this.core});

  final CoreController core;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final problem = core.unavailable;
    final portTaken =
        problem != null &&
        (problem.problem == CoreProblem.portInUse ||
            problem.problem == CoreProblem.refused);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (problem == null || problem.problem == CoreProblem.starting) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l.startingCore, style: theme.textTheme.titleMedium),
            ] else ...[
              Icon(
                Icons.power_off_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(l.cantReachCore, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                describeProblem(l, problem),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (portTaken && core.moveStoppedCore != null)
                    FilledButton.icon(
                      onPressed: () async {
                        final port = await showPortDialog(
                          context,
                          taken: problem.detail,
                        );
                        if (port != null && context.mounted) {
                          await runShowingErrors(
                            context,
                            () => core.setAppPort(port),
                          );
                        }
                      },
                      icon: const Icon(Icons.settings_ethernet_rounded),
                      label: Text(l.changePort),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: core.retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l.retry),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
