import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arman_vpn/app_settings.dart';
import 'package:arman_vpn/core/core_api.dart';
import 'package:arman_vpn/core/core_controller.dart';
import 'package:arman_vpn/core/models.dart';
import 'package:arman_vpn/l10n/app_localizations.dart';
import 'package:arman_vpn/l10n/app_localizations_en.dart';
import 'package:arman_vpn/ui/app.dart' show VpnApp, shellStructureOf;
import 'package:arman_vpn/ui/mobile_shell.dart';
import 'package:arman_vpn/ui/settings_page.dart'
    show settingsIndex, SettingsSection;
import 'package:arman_vpn/ui/zed/zed_connect.dart' show ZedPhase;
import 'package:arman_vpn/ui/zed/zed_connect_glass.dart'
    show GlassSwitch, zLook;
import 'package:arman_vpn/ui/zed/zed_kit.dart';
import 'package:arman_vpn/ui/zed/zed_prefs.dart';
import 'package:arman_vpn/ui/zed/zed_theme.dart';

/// Behavioural proof for the +259 round:
///  * the nav styles are the source's distinct bars (underline has
///    an underline, expressive fills only the selected pill, the
///    floating styles show no labels, minimal has its dot);
///  * Bento's nav-style setting reaches the phone's bar (before, the
///    Bento dock rendered for every style — the setting was a no-op
///    on the phone);
///  * the shell rebuilds on structural core changes only, while the
///    traffic panel keeps its live updates from its own listener;
///  * the custom toggles/swatches/segments carry accessible names.

const _tabs = [
  ZedTab(icon: Icons.home_rounded, label: 'Home'),
  ZedTab(icon: Icons.settings_rounded, label: 'Settings'),
];

Future<void> _pumpBar(
  WidgetTester tester,
  ZedNavStyle style, {
  int index = 0,
  ValueChanged<int>? onSelect,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ZedBottomBar(
            style: style,
            tabs: _tabs,
            index: index,
            onSelect: onSelect ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _barHeight(WidgetTester tester) =>
    tester.getSize(find.byType(ZedBottomBar)).height;

void main() {
  _deepseek259Tests();
  group('nav styles are distinct bars (NavBar.kt)', () {
    testWidgets('floating pill: no labels, filled selected circle', (
      tester,
    ) async {
      await _pumpBar(tester, ZedNavStyle.floatingPill);
      expect(_barHeight(tester), 64);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('compact dock: the smaller floating toolbar', (tester) async {
      await _pumpBar(tester, ZedNavStyle.compactDock);
      expect(_barHeight(tester), 54);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('expressive pill: only the selected item is labelled', (
      tester,
    ) async {
      await _pumpBar(tester, ZedNavStyle.expressivePill);
      expect(_barHeight(tester), 58);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('full bar: labels and the indicator pill', (tester) async {
      await _pumpBar(tester, ZedNavStyle.fullBar);
      expect(_barHeight(tester), 80);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byKey(const Key('zed-nav-underline')), findsNothing);
    });

    testWidgets('underline: a bar over the selected icon, no indicator', (
      tester,
    ) async {
      await _pumpBar(tester, ZedNavStyle.underline);
      expect(_barHeight(tester), 80);
      expect(find.text('Home'), findsOneWidget);
      final underline = find.byKey(const Key('zed-nav-underline'));
      expect(underline, findsOneWidget);
      expect(tester.getSize(underline), const Size(24, 3));
    });

    testWidgets('minimal: no labels, a dot under the selected item', (
      tester,
    ) async {
      await _pumpBar(tester, ZedNavStyle.minimal);
      expect(_barHeight(tester), 68);
      expect(find.text('Home'), findsNothing);
      expect(find.byKey(const Key('zed-nav-minimal-dot')), findsOneWidget);
    });

    testWidgets('every style selects on tap', (tester) async {
      for (final style in ZedNavStyle.values) {
        var picked = -1;
        await _pumpBar(tester, style, onSelect: (i) => picked = i);
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpAndSettle();
        expect(picked, 1, reason: '$style must select the tapped tab');
      }
    });
  });

  group('Bento nav style reaches the phone bar', () {
    CoreController deadCore() => CoreController(
      () async => throw const CoreUnavailable(CoreProblem.noCore),
      pollInterval: const Duration(hours: 1),
    );

    Future<void> pumpShell(WidgetTester tester, ZedNavStyle style) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = AppSettings();
      settings.setZed(
        ZedPrefs(
          design: ZedDesign.bento,
          bento: BentoPrefs(navStyle: style),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: VpnApp.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MobileShell(
            core: deadCore(),
            settings: settings,
            banner: null,
            noCore: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Dock style shows the Bento dock', (tester) async {
      await pumpShell(tester, ZedNavStyle.dock);
      expect(find.byType(BentoDock), findsOneWidget);
      expect(find.byType(ZedBottomBar), findsNothing);
    });

    testWidgets('Full bar style shows the shared bar, not the dock', (
      tester,
    ) async {
      await pumpShell(tester, ZedNavStyle.fullBar);
      expect(find.byType(BentoDock), findsNothing);
      expect(find.byType(ZedBottomBar), findsOneWidget);
    });

    testWidgets('Underline style shows the shared bar with its underline', (
      tester,
    ) async {
      await pumpShell(tester, ZedNavStyle.underline);
      expect(find.byType(BentoDock), findsNothing);
      expect(find.byKey(const Key('zed-nav-underline')), findsOneWidget);
    });
  });

  group('shell structure gate', () {
    test('structure changes only on structural facts', () async {
      final api = _ShellApi();
      final core = CoreController(
        () async => api,
        pollInterval: const Duration(hours: 1),
      );
      final before = shellStructureOf(core);
      expect(before.hasStatus, isFalse);
      expect(before.needsAttention, 0);
      // refresh() connects lazily; poll until the first answer lands
      // (a refresh racing another returns at once by design).
      for (var i = 0; i < 100 && core.status == null; i++) {
        await core.refresh(accountsToo: true);
        if (core.status == null) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }
      final live = shellStructureOf(core);
      expect(live.hasStatus, isTrue);
      expect(live.needsAttention, 0);
      // A pure traffic change is NOT structural.
      api.upRate = 5000;
      await core.refresh();
      expect(shellStructureOf(core), live);
      // An account needing sign-in IS structural (the rail badge).
      api.reauth = true;
      await core.refresh(accountsToo: true);
      final badge = shellStructureOf(core);
      expect(badge.needsAttention, 1);
      expect(badge, isNot(live));
      core.dispose();
    });

    testWidgets('traffic panel follows the poll; the badge follows accounts', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ShellApi();
      final core = CoreController(
        () async => api,
        pollInterval: const Duration(hours: 1),
      );
      await tester.pumpWidget(VpnApp(core: core, settings: AppSettings()));
      core.start();
      await tester.pumpAndSettle();
      expect(find.textContaining('0 B/s'), findsWidgets);
      // The live rate moves with the poll — the panel's own listener,
      // not a shell rebuild.
      api.upRate = 2048;
      await core.refresh();
      await tester.pumpAndSettle();
      expect(find.textContaining('2.0 KB/s'), findsWidgets);
      // An account needing sign-in raises the rail badge.
      expect(find.text('1'), findsNothing);
      api.reauth = true;
      await core.refresh(accountsToo: true);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      core.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });

  group('accessible names on the custom controls', () {
    /// The Semantics widget in the tree carrying [label].
    Finder semanticsWith(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    );

    testWidgets('GlassSwitch announces its row name and state', (tester) async {
      final tokens = glassTokensFor(GlassPrefs(), false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlassSwitch(
                tokens: tokens,
                value: true,
                onChanged: (_) {},
                semanticLabel: 'Glass lists',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.bySemanticsLabel('Glass lists'));
      expect(node.label, 'Glass lists');
      final widget = tester.widget<Semantics>(semanticsWith('Glass lists'));
      expect(widget.properties.toggled, isTrue);
    });

    testWidgets('swatches are named buttons with a 44 dp hit box', (
      tester,
    ) async {
      var picked = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZedSwatchRow(
              title: 'Tint',
              colors: const [Colors.red, Colors.blue],
              names: const ['Red', 'Blue'],
              selected: 1,
              onSelect: (i) => picked = i,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final blue = tester.widget<Semantics>(semanticsWith('Blue'));
      expect(blue.properties.button, isTrue);
      expect(blue.properties.selected, isTrue);
      final red = tester.widget<Semantics>(semanticsWith('Red'));
      expect(red.properties.selected, isFalse);
      // The corner of the 44 dp hit box (outside the 34 dp circle)
      // still selects.
      final box = tester.getRect(find.bySemanticsLabel('Red'));
      expect(box.width, 44);
      await tester.tapAt(box.topLeft + const Offset(3, 3));
      expect(picked, 0);
    });

    testWidgets('segmented options announce as selectable buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZedSegmentedRow<String>(
              title: 'Mode',
              options: const [('a', 'Alpha'), ('b', 'Beta')],
              value: 'b',
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final beta = tester.widget<Semantics>(semanticsWith('Beta'));
      expect(beta.properties.button, isTrue);
      expect(beta.properties.selected, isTrue);
      final alpha = tester.widget<Semantics>(semanticsWith('Alpha'));
      expect(alpha.properties.button, isTrue);
      expect(alpha.properties.selected, isFalse);
    });
  });
}

/// A running core with a mutable traffic rate and one account that
/// can start needing sign-in.
class _ShellApi implements CoreApi {
  int upRate = 0;
  bool reauth = false;

  @override
  Future<CoreStatus> status() async => CoreStatus.fromJson({
    'state': {'phase': 'running', 'message': ''},
    'system_proxy': 'set',
    'system_proxy_supported': true,
    'proxy': {'listen': '127.0.0.1:10810', 'country_name': 'Netherlands'},
    'traffic': {'up': 0, 'down': 0, 'up_rate': upRate, 'down_rate': 0},
    'accounts': {'total': 1},
    'version': '9.9',
  });

  @override
  Future<AccountList> accounts() async => AccountList.fromJson({
    'accounts': [
      {
        'id': 'alice',
        'name': 'alice@example.com',
        'email': 'alice@example.com',
        'enabled': true,
        'active': true,
        'status': reauth ? 'reauth_required' : 'ready',
        'usage': {'limit_bytes': 50 << 30, 'remaining_bytes': 30 << 30},
        'used_percent': 40,
      },
    ],
    'switch_threshold_percent': 90,
  });

  @override
  void close() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// DeepSeek +259 adjudicated fixes
// ---------------------------------------------------------------------------

void _deepseek259Tests() {
  group('search index section mapping (A3/A11)', () {
    test('upstream proxy is indexed under its own section', () {
      final l = AppLocalizationsEn();
      final index = settingsIndex(l);
      expect(index, contains((SettingsSection.upstreamProxy, l.upstreamProxy)));
      expect(
        index,
        isNot(contains((SettingsSection.advanced, l.upstreamProxy))),
      );
    });

    test('remove-TUN-service is indexed once, under advanced', () {
      final l = AppLocalizationsEn();
      final hits = settingsIndex(l)
          .where((e) => e.$2 == l.removeTunService)
          .toList();
      expect(hits, [(SettingsSection.advanced, l.removeTunService)]);
    });
  });

  group('ZLook value equality (A42)', () {
    test('identical looks are equal; a tint change is not', () {
      final a = zLook(ZedPhase.busy, true, const Color(0xFF7C6CF0));
      final b = zLook(ZedPhase.busy, true, const Color(0xFF7C6CF0));
      final c = zLook(ZedPhase.busy, true, const Color(0xFFF06C9B));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  testWidgets('glass tab bar items are named buttons (A38)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlassTabBar(
            tokens: glassTokensFor(GlassPrefs(), true),
            tabs: const [
              ZedTab(icon: Icons.home_rounded, label: 'Home'),
              ZedTab(icon: Icons.settings_rounded, label: 'Settings'),
            ],
            index: 0,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    // Both bar states are in the tree (full + shrunk circle), so
    // assert a matching node exists rather than the only one.
    final all = [
      for (final e in find.byType(Semantics).evaluate())
        (e.widget as Semantics).properties,
    ];
    expect(
      all.any(
        (p) => p.label == 'Home' && p.button == true && p.selected == true,
      ),
      isTrue,
    );
    expect(
      all.any(
        (p) =>
            p.label == 'Settings' && p.button == true && p.selected == false,
      ),
      isTrue,
    );
    handle.dispose();
  });
}
