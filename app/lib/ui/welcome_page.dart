import 'dart:io';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../app_settings.dart';
import '../core/android_core.dart';
import '../core/core_controller.dart';
import '../l10n/app_localizations.dart';
import 'widgets.dart';
import 'zed/zed_glass.dart';
import 'zed/zed_theme.dart';

/// The first run: the user picks a language and a country, and the
/// country's sites go directly (the core's routing region).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.core, required this.settings});

  final CoreController core;
  final AppSettings settings;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late String _language;
  late String _region;

  /// A manual region choice always wins over desktop language suggestions.
  bool _regionPicked = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final system = PlatformDispatcher.instance.locale;
    _language = widget.settings.language.isNotEmpty
        ? widget.settings.language
        : AppSettings.languageFor(system);
    _region =
        widget.settings.firstRunRegion ??
        AppSettings.suggestedRegion(_language, system.countryCode);
  }

  void _pickLanguage(String language) {
    setState(() {
      _language = language;
      if (widget.settings.firstRunRegion == null && !_regionPicked) {
        _region = AppSettings.regionForLanguage(language) ?? _region;
      }
    });
    // Show the page in the chosen language at once.
    widget.settings.update(language: language);
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    final region = _region;
    await runShowingErrors(
      context,
      () => widget.core.editSettings((config) {
        final routing = config['routing'];
        if (routing is! Map<String, Object?>) return;
        routing['enabled'] = region.isNotEmpty;
        if (region.isNotEmpty) routing['region'] = region;
      }),
    );
    widget.settings.update(language: _language, firstRun: false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final body = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Panel(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.welcomeBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: InputDecoration(
                    labelText: l.language,
                    prefixIcon: const Icon(Icons.translate_rounded),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => _pickLanguage(v!),
                  items: [
                    for (final code in AppSettings.supportedLanguages)
                      DropdownMenuItem(
                        value: code,
                        child: Text(
                          languageNames[code]!,
                          style: languageStyle(code),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_region),
                  initialValue: _region,
                  decoration: InputDecoration(
                    labelText: l.region,
                    helperText: l.routingDirectHint,
                    helperMaxLines: 3,
                    prefixIcon: const Icon(Icons.alt_route_rounded),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() {
                    _region = v!;
                    _regionPicked = true;
                  }),
                  items: [
                    for (final r in AppSettings.regions)
                      DropdownMenuItem(value: r, child: Text(regionName(l, r))),
                  ],
                ),
                const SizedBox(height: 20),
                // "Make it yours": the design step of the first run,
                // as in ZedSecure's onboarding — picking a design (and
                // a Bento palette) re-themes the app at once, so the
                // choice is its own live preview. The design names
                // are ZedSecure's own words, as in Settings.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l.uiDesign, style: theme.textTheme.titleSmall),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (design, label) in [
                      (UiDesign.bento, 'Bento'),
                      (UiDesign.pixel, l.designPixel),
                      (UiDesign.old, l.designOld),
                      (UiDesign.glass, 'Glass'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: widget.settings.uiDesign == design,
                        onSelected: (_) =>
                            widget.settings.update(uiDesign: design),
                      ),
                  ],
                ),
                if (widget.settings.zed.design == ZedDesign.bento) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in bentoPalettes.entries)
                        Tooltip(
                          message: entry.key.name,
                          // The visible dot stays 30 dp, but the
                          // hit area is 48 dp and the swatch reads
                          // as a selectable button with its state —
                          // a bare 30 dp GestureDetector was
                          // neither (round 3, DeepSeek ds3-10).
                          child: Semantics(
                            button: true,
                            selected:
                                widget.settings.zed.bentoPalette == entry.key,
                            label: entry.key.name,
                            onTap: () => widget.settings.update(
                              zed: widget.settings.zed.copyWith(
                                bentoPalette: entry.key,
                              ),
                            ),
                            child: GestureDetector(
                              onTap: () => widget.settings.update(
                                zed: widget.settings.zed.copyWith(
                                  bentoPalette: entry.key,
                                ),
                              ),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: entry.value.seed,
                                      border: Border.all(
                                        color:
                                            widget.settings.zed.bentoPalette ==
                                                entry.key
                                            ? theme.colorScheme.onSurface
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  // A TV starts on Start: the remote's OK goes on with
                  // the language and the country it found.
                  autofocus: Platform.isAndroid && AndroidCore.isTv,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _saving ? null : _start,
                  child: Text(l.start),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Under Glass the scaffold turns transparent (the design's
    // theme), so the page needs the wallpaper behind its panel
    // like every in-shell surface — picking Glass on this page
    // re-themes this very scaffold live (round-3 integration
    // finding F2).
    return Scaffold(
      body: widget.settings.zed.design == ZedDesign.glass
          ? Stack(
              children: [
                Positioned.fill(
                  child: GlassWallpaperView(
                    prefs: widget.settings.zed,
                    dark: theme.brightness == Brightness.dark,
                  ),
                ),
                body,
              ],
            )
          : body,
    );
  }
}
