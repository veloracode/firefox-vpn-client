import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../app_settings.dart';
import '../core/android_core.dart';
import '../core/core_controller.dart';
import '../l10n/app_localizations.dart';
import 'about_page.dart';
import 'format.dart';
import 'announcement_panel.dart';
import 'accounts_page.dart';
import 'foxy_accounts_page.dart';
import 'foxy_overview_page.dart';
import 'logs_page.dart';
import 'overview_page.dart';
import 'servers_page.dart';
import 'settings_page.dart';
import 'widgets.dart';
import 'zed_old_home.dart';
import 'zed_pixel_home.dart';
import 'zed_portal_home.dart';

/// The phone layout: two tabs, Home and Settings, as phone apps have. The
/// rest (accounts, servers, each group of settings, logs, about) opens as a
/// page of its own with the system's back button.
class MobileShell extends StatefulWidget {
  const MobileShell({
    super.key,
    required this.core,
    required this.settings,
    required this.banner,
    this.noCore,
  });

  final CoreController core;
  final AppSettings settings;

  /// Shown above the page when the core stopped answering.
  final Widget? banner;

  /// Shown in place of the pages until the core first answers.
  final Widget? noCore;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    AndroidCore.homeRequests.addListener(_openHome);
  }

  void _openHome() => setState(() => _tab = 0);

  @override
  void dispose() {
    AndroidCore.homeRequests.removeListener(_openHome);
    super.dispose();
  }

  /// Opens [page] under a top bar named [title]; it follows the core.
  void _push(String title, Widget Function() page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ListenableBuilder(
          listenable: widget.core,
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(
              top: false,
              child: OwnTopBar(child: _readable(page())),
            ),
          ),
        ),
      ),
    );
  }

  /// [page] no wider than a line can be read on a tablet; the home page
  /// keeps the whole width for its colors and limits its own content.
  static Widget _readable(Widget page) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: page,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final core = widget.core;
    final settings = widget.settings;
    void openServers() =>
        _push(l.navServers, () => ServersPage(core: core, settings: settings));
    // The design is the user's (Settings, General): FoxyVPN's accounts
    // page for every design but the classic one.
    void openAccounts() => _push(
      l.navAccounts,
      () => settings.uiDesign == UiDesign.classic
          ? AccountsPage(core: core, settings: settings)
          : FoxyAccountsPage(core: core),
    );
    void openConnection() => _push(
      l.sectionConnection,
      () => SettingsPage(
        core: core,
        settings: settings,
        section: SettingsSection.connection,
      ),
    );
    void openUpstreamProxy() => _push(
      l.upstreamProxy,
      () => SettingsPage(
        core: core,
        settings: settings,
        section: SettingsSection.upstreamProxy,
      ),
    );
    final home = switch (settings.uiDesign) {
      UiDesign.pixel => ZedPixelHome(
        core: core,
        settings: settings,
        onOpenServers: openServers,
        onOpenAccounts: openAccounts,
      ),
      UiDesign.portal => ZedPortalHome(
        core: core,
        settings: settings,
        onOpenServers: openServers,
        onOpenAccounts: openAccounts,
      ),
      UiDesign.old => ZedOldHome(
        core: core,
        settings: settings,
        onOpenServers: openServers,
        onOpenAccounts: openAccounts,
      ),
      UiDesign.foxy => FoxyOverviewPage(
        core: core,
        settings: settings,
        onOpenServers: openServers,
        onOpenAccounts: openAccounts,
        onOpenConnection: openConnection,
      ),
      UiDesign.classic => OverviewPage(
        core: core,
        settings: settings,
        onOpenServers: openServers,
        onOpenAccounts: openAccounts,
        onOpenConnection: openConnection,
        onOpenUpstreamProxy: openUpstreamProxy,
        phone: true,
      ),
    };
    final page =
        widget.noCore ??
        (_tab == 0
            ? home
            : _readable(
                _SettingsList(
                  onOpenServers: openServers,
                  onOpenAccounts: openAccounts,
                  push: _push,
                  core: core,
                  settings: settings,
                ),
              ));
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        body: SafeArea(
          // The home page's hero reaches under the status bar.
          top: _tab != 0 || widget.noCore != null || widget.banner != null,
          child: AnnouncementOverlay(
            settings: settings,
            onOpenUpdates: () =>
                _push(l.checkUpdates, () => AboutPage(core: core)),
            child: Column(
              children: [
                ?widget.banner,
                Expanded(child: page),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _themed(
          context,
          // The dark home page has its own night colors.
          home:
              _tab == 0 &&
              widget.noCore == null &&
              Theme.of(context).brightness == Brightness.dark,
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: l.navHome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: l.navSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The home page's midnight theme around [child] while home shows.
  Widget _themed(
    BuildContext context, {
    required bool home,
    required Widget child,
  }) => home
      ? Theme(data: midnightTheme(Theme.of(context)), child: child)
      : child;
}

/// The Settings tab: what the app manages, the groups of settings, and the
/// app's own pages.
class _SettingsList extends StatefulWidget {
  const _SettingsList({
    required this.onOpenServers,
    required this.onOpenAccounts,
    required this.push,
    required this.core,
    required this.settings,
  });

  final VoidCallback onOpenServers;
  final VoidCallback onOpenAccounts;
  final void Function(String title, Widget Function() page) push;
  final CoreController core;
  final AppSettings settings;

  @override
  State<_SettingsList> createState() => _SettingsListState();
}

class _SettingsListState extends State<_SettingsList> {
  /// What was typed, folded for matching; empty shows the whole list.
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final core = widget.core;
    final settings = widget.settings;
    final push = widget.push;
    final onOpenServers = widget.onOpenServers;
    final onOpenAccounts = widget.onOpenAccounts;
    bool matches(String name) =>
        _query.isEmpty || foldForSearch(name).contains(_query);
    // A group keeps only the rows whose name matches, and goes away itself
    // when none of them does.
    Widget? group(String title, List<(String, Widget)> tiles) {
      final kept = [
        for (final (name, tile) in tiles)
          if (matches(name)) tile,
      ];
      return kept.isEmpty ? null : SettingsGroup(title: title, tiles: kept);
    }

    Widget tile(IconData icon, String title, VoidCallback onTap) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      // Mirrors itself in right-to-left languages.
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
    void open(SettingsSection section, String name) => push(
      name,
      () => SettingsPage(core: core, settings: settings, section: section),
    );
    (String, Widget) section(
      SettingsSection section,
      IconData icon,
      String name,
    ) => (name, tile(icon, name, () => open(section, name)));
    (String, Widget) row(IconData icon, String name, VoidCallback onTap) =>
        (name, tile(icon, name, onTap));
    // The sections this list opens: TUN is not among them, and the app's
    // port and web dashboard are a computer's.
    final offered = {
      SettingsSection.general,
      SettingsSection.connection,
      SettingsSection.routing,
      SettingsSection.dns,
      SettingsSection.relay,
      SettingsSection.fragment,
      SettingsSection.upstreamProxy,
      if (!Platform.isAndroid) SettingsSection.advanced,
    };
    // The sections' own settings, when something was typed: each one under
    // the section that holds it, so one tap opens it.
    final hits = _query.isEmpty
        ? const <(SettingsSection, String)>[]
        : [
            for (final entry in settingsIndex(l))
              if (foldForSearch(entry.$2).contains(_query) &&
                  offered.contains(entry.$1) &&
                  settingOnThisPlatform(l, entry.$2))
                entry,
          ];
    final groups = [
      ?group(l.sectionGeneral, [
        // Language and theme first, what someone looks for before anything
        // else, with which country and account; then how the traffic goes,
        // what helps when Mozilla is blocked, and the app itself.
        section(
          SettingsSection.general,
          Icons.tune_rounded,
          l.sectionGeneral,
        ),
        row(Icons.public_rounded, l.navServers, onOpenServers),
        row(Icons.people_outline_rounded, l.navAccounts, onOpenAccounts),
      ]),
      ?group(l.groupNetwork, [
          section(
            SettingsSection.connection,
            Icons.vpn_lock_outlined,
            l.sectionConnection,
          ),
          section(
            SettingsSection.routing,
            Icons.alt_route_rounded,
            l.sectionRouting,
          ),
          section(SettingsSection.dns, Icons.dns_rounded, l.sectionDns),
        ]),
      ?group(l.sectionBypass, [
          section(SettingsSection.relay, Icons.cloud_outlined, l.apiRelay),
          section(
            SettingsSection.fragment,
            Icons.content_cut_rounded,
            l.tlsFragment,
          ),
          section(
            SettingsSection.upstreamProxy,
            Icons.lan_outlined,
            l.upstreamProxy,
          ),
        ]),
      ?group(l.groupApp, [
          // The app's port and the web dashboard: computers only (a narrow
          // window shows this layout too).
          if (!Platform.isAndroid)
            section(
              SettingsSection.advanced,
              Icons.build_outlined,
              l.sectionAdvanced,
            ),
          row(
            Icons.receipt_long_outlined,
            l.navLogs,
            () => push(l.navLogs, () => LogsPage(core: core)),
          ),
          row(
            Icons.info_outline_rounded,
            l.navAbout,
            () => push(l.navAbout, () => AboutPage(core: core)),
          ),
        ]),
    ];
    return ListView(
      padding: pagePadding(context),
      children: [
        PageTitle(l.settingsTitle),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = foldForSearch(v)),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: l.search,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (groups.isEmpty && hits.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Text(
              l.settingsNoMatch,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ...groups,
        if (hits.isNotEmpty)
          SettingsGroup(
            title: l.settingsTitle,
            tiles: [
              for (final (section, name) in hits)
                ListTile(
                  leading: const Icon(Icons.chevron_right_rounded),
                  title: Text(name),
                  subtitle: Text(settingsSectionName(l, section)),
                  onTap: () => open(section, settingsSectionName(l, section)),
                ),
            ],
          ),
      ],
    );
  }
}
